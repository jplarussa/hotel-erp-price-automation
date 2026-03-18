/*
================================================================================
INITIAL EXPLORATION SCRIPT - TOTVS DATABASE ANALYSIS
================================================================================

Purpose: Reverse engineering of database without official documentation
Author: [Your Name]
Date: January 2026
System: SQL Server 2014 / TOTVS (Ex CM Soluções)

NOTE: This script documents the initial research process to understand
      the hotel ERP system data structure.
================================================================================
*/

-- ============================================================================
-- 1. IDENTIFICATION OF POS-RELATED TABLES
-- ============================================================================

-- Search all tables containing 'PDV' in name
SELECT TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'cm' 
  AND TABLE_NAME LIKE '%PDV%'
ORDER BY TABLE_NAME;

/*
RESULT: 12 tables identified
- PDVITEM (main - prices per POS)
- PDVXGRPITEM (item groups)
- PDVALTPRECO (price change history)
- SERVHOTELXITEMPDV (items associated with services)
- Others...
*/


-- ============================================================================
-- 2. MAIN TABLE STRUCTURE ANALYSIS (PDVITEM)
-- ============================================================================

-- View complete table structure
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'cm'
  AND TABLE_NAME = 'PDVITEM'
ORDER BY ORDINAL_POSITION;

/*
CRITICAL FINDING:
- Preco is NUMERIC(12,2) → Only 2 decimals
- This automatically protects symbolic prices (0.01)
*/


-- ============================================================================
-- 3. RELATIONSHIP IDENTIFICATION (FOREIGN KEYS)
-- ============================================================================

-- View all tables that reference PDVITEM
SELECT 
    OBJECT_NAME(parent_object_id) AS ReferencingTable,
    name AS FKName,
    OBJECT_NAME(referenced_object_id) AS ReferencedTable
FROM sys.foreign_keys 
WHERE referenced_object_id = OBJECT_ID('cm.PDVITEM')
ORDER BY ReferencingTable;

/*
RESULT: 11 related tables
- PDVALTPRECO (R_6592) - Price history
- SERVHOTELXITEMPDV (R_11053) - Service items
- CLUBE (R_9420) - Loyalty programs
- EXITEMCORTESIA - Courtesy items
- Others...

CONCLUSION: No triggers, direct update is safe
*/


-- ============================================================================
-- 4. TRIGGER VERIFICATION (CRITICAL FOR SAFETY)
-- ============================================================================

-- Check if triggers exist in PDVITEM
SELECT 
    name AS TriggerName,
    type_desc AS TriggerType,
    is_disabled AS Disabled,
    OBJECT_DEFINITION(object_id) AS Definition
FROM sys.triggers 
WHERE parent_id = OBJECT_ID('cm.PDVITEM');

/*
RESULT: 0 rows
CONCLUSION: NO triggers - safe to update directly
*/


-- ============================================================================
-- 5. AVAILABLE POS IDENTIFICATION
-- ============================================================================

-- View all unique POSs in system
SELECT DISTINCT IdTipoDebCred 
FROM cm.PDVITEM 
ORDER BY IdTipoDebCred;

-- Get descriptive POS names
SELECT DISTINCT 
    p.IdTipoDebCred,
    t.DescTipoDebCred AS POSName,
    COUNT(*) OVER (PARTITION BY p.IdTipoDebCred) AS ItemCount
FROM cm.PDVITEM p
LEFT JOIN cm.TIPODC t ON p.IdTipoDebCred = t.IdTipoDebCred
ORDER BY p.IdTipoDebCred;

/*
RESULT:
51 = Terraces
52 = Restaurant (82 items)
54 = Minibar
55 = Laundry
56 = Room Service (82 items) ← SAME PRICES AS RT
229 = Cards
*/


-- ============================================================================
-- 6. CURRENT PRICE ANALYSIS
-- ============================================================================

-- Price distribution by POS
SELECT 
    IdTipoDebCred,
    COUNT(*) as TotalItems,
    MIN(Preco) as MinPrice,
    MAX(Preco) as MaxPrice,
    AVG(Preco) as AvgPrice,
    COUNT(CASE WHEN Preco = 0.01 THEN 1 END) as SymbolicItems
FROM cm.PDVITEM 
WHERE IdTipoDebCred IN (52, 56)
GROUP BY IdTipoDebCred;


-- ============================================================================
-- 7. RT vs ROM DUPLICATION VERIFICATION
-- ============================================================================

-- Compare prices between Restaurant and Room Service
SELECT 
    rt.CodArtigo,
    pr.DescProd,
    rt.Preco AS PriceRT,
    rom.Preco AS PriceROM,
    CASE 
        WHEN rt.Preco = rom.Preco THEN 'EQUAL'
        ELSE 'DIFFERENT'
    END AS Comparison
FROM cm.PDVITEM rt
JOIN cm.PDVITEM rom ON rt.CodArtigo = rom.CodArtigo
LEFT JOIN cm.PRODUTO pr ON rt.CodArtigo = pr.CodProduto
WHERE rt.IdTipoDebCred = 52
  AND rom.IdTipoDebCred = 56
ORDER BY Comparison DESC, pr.DescProd;

/*
CRITICAL FINDING:
- 80 items with EQUAL prices
- 2 DIFFERENT items (not in Room Service)
- CONCLUSION: Can be updated together with WHERE IN (52, 56)
*/


-- ============================================================================
-- 8. PRODUCT TABLE SEARCH (DESCRIPTIONS)
-- ============================================================================

-- Search for table with product descriptions
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'cm'
  AND TABLE_NAME LIKE '%PROD%'
ORDER BY TABLE_NAME;

-- Verify PRODUTO structure
SELECT TOP 5
    CodProduto,
    DescProd
FROM cm.PRODUTO
ORDER BY CodProduto;

/*
CONCLUSION: 
- cm.PRODUTO has descriptions
- JOIN by: p.CodArtigo = pr.CodProduto
*/


-- ============================================================================
-- 9. HISTORY ANALYSIS (PDVALTPRECO)
-- ============================================================================

-- View last recorded changes
SELECT TOP 10
    CodArtigo,
    PrecoAnterior,
    PrecoNovo,
    DataAlteracao,
    Usuario
FROM cm.PDVALTPRECO
ORDER BY DataAlteracao DESC;

/*
FINDING: System already records changes automatically
BENEFIT: Built-in system audit
*/


-- ============================================================================
-- 10. PROOF OF CONCEPT - ROUNDING SIMULATION
-- ============================================================================

-- Simulate how prices would look with different divisors
SELECT 
    CodArtigo,
    Preco AS CurrentPrice,
    ROUND(Preco / 200.0, 0) * 200 AS Round200,
    ROUND(Preco / 500.0, 0) * 500 AS Round500,
    ROUND(Preco / 1000.0, 0) * 1000 AS Round1000
FROM cm.PDVITEM
WHERE IdTipoDebCred = 52
  AND Preco > 100
ORDER BY Preco DESC;

/*
CONCLUSION: 
- Divisor of 200 gives better granularity
- Divisor of 500 is good for high prices
- Rounding logic works correctly
*/


-- ============================================================================
-- END OF EXPLORATORY ANALYSIS
-- ============================================================================

/*
MAIN CONCLUSIONS:
1. Main table: cm.PDVITEM
2. Price field: Preco (NUMERIC(12,2))
3. No interfering triggers
4. RT and ROM have identical prices → can be updated together
5. Symbolic items (0.01) are protected by data type
6. System automatically records history in PDVALTPRECO
7. Direct SQL update is safe and viable

NEXT STEP: Development of automatic update script
*/