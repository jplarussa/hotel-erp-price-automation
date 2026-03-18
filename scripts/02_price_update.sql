/*
================================================================================
MAIN SCRIPT - PRICE UPDATE AND ROUNDING
================================================================================
System: SQL Server 2014 / TOTVS
Purpose: Round prices to configurable multiples after applying
         percentage increase via TOTVS system module

PREREQUISITE: Have executed percentage increase from system POS module
IMPORTANT: Execute outside operating hours
================================================================================
*/

USE cm;
GO

-- ============================================================================
-- STEP 1: PREVIEW - Visualize changes without executing
-- ============================================================================

-- MODIFY: Change divisor as needed (200, 500, 1000)
DECLARE @Divisor INT = 200;

SELECT 
    p.CodArtigo,
    pr.DescProd AS Product,
    p.Preco AS CurrentPrice,
    CASE 
        WHEN p.Preco < 2 THEN p.Preco
        ELSE ROUND(p.Preco / @Divisor, 0) * @Divisor
    END AS NewPrice,
    CASE 
        WHEN p.Preco < 2 THEN 0
        ELSE (ROUND(p.Preco / @Divisor, 0) * @Divisor) - p.Preco
    END AS Difference,
    p.IdTipoDebCred AS POS
FROM cm.PDVITEM p
LEFT JOIN cm.PRODUTO pr ON p.CodArtigo = pr.CodProduto
WHERE p.IdTipoDebCred IN (52, 56)  -- RT and ROM
ORDER BY p.IdTipoDebCred, p.Preco DESC;

GO


-- ============================================================================
-- STEP 2: CREATE BACKUPS
-- ============================================================================

-- Clean previous backups if they exist
IF OBJECT_ID('cm.PDVITEM_BACKUP_REDONDEO_RT', 'U') IS NOT NULL
    DROP TABLE cm.PDVITEM_BACKUP_REDONDEO_RT;

IF OBJECT_ID('cm.PDVITEM_BACKUP_REDONDEO_ROM', 'U') IS NOT NULL
    DROP TABLE cm.PDVITEM_BACKUP_REDONDEO_ROM;

-- Create backups
SELECT * 
INTO cm.PDVITEM_BACKUP_REDONDEO_RT
FROM cm.PDVITEM 
WHERE IdTipoDebCred = 52;

SELECT * 
INTO cm.PDVITEM_BACKUP_REDONDEO_ROM
FROM cm.PDVITEM 
WHERE IdTipoDebCred = 56;

-- Verify creation
SELECT 'RT' AS POS, COUNT(*) AS Records
FROM cm.PDVITEM_BACKUP_REDONDEO_RT
UNION ALL
SELECT 'ROM' AS POS, COUNT(*) AS Records
FROM cm.PDVITEM_BACKUP_REDONDEO_ROM;

GO


-- ============================================================================
-- STEP 3: EXECUTE UPDATE
-- ============================================================================

-- MODIFY: Change divisor as needed
UPDATE cm.PDVITEM 
SET Preco = CASE 
    WHEN Preco < 2 THEN Preco
    ELSE ROUND(Preco / 200.0, 0) * 200  -- MODIFY DIVISOR HERE
END
WHERE IdTipoDebCred IN (52, 56)
  AND Preco >= 2;

-- View number of affected records
SELECT @@ROWCOUNT AS UpdatedRecords;

GO


-- ============================================================================
-- STEP 4: VERIFICATION
-- ============================================================================

-- Count detected changes
SELECT COUNT(*) AS ChangesDetected_RT
FROM (
    SELECT * FROM cm.PDVITEM WHERE IdTipoDebCred = 52
    EXCEPT 
    SELECT * FROM cm.PDVITEM_BACKUP_REDONDEO_RT
) changes;

SELECT COUNT(*) AS ChangesDetected_ROM
FROM (
    SELECT * FROM cm.PDVITEM WHERE IdTipoDebCred = 56
    EXCEPT 
    SELECT * FROM cm.PDVITEM_BACKUP_REDONDEO_ROM
) changes;

-- View change details - RT
SELECT TOP 20
    b.CodArtigo,
    pr.DescProd,
    b.Preco AS Previous,
    a.Preco AS New,
    a.Preco - b.Preco AS Difference
FROM cm.PDVITEM_BACKUP_REDONDEO_RT b
JOIN cm.PDVITEM a ON a.CodArtigo = b.CodArtigo AND a.IdTipoDebCred = b.IdTipoDebCred
LEFT JOIN cm.PRODUTO pr ON b.CodArtigo = pr.CodProduto
WHERE b.Preco != a.Preco
ORDER BY ABS(a.Preco - b.Preco) DESC;

GO


-- ============================================================================
-- ROLLBACK (Execute only if reverting is necessary)
-- ============================================================================

/*
-- UNCOMMENT ONLY IF YOU NEED TO REVERT

UPDATE cm.PDVITEM
SET Preco = b.Preco
FROM cm.PDVITEM p
JOIN cm.PDVITEM_BACKUP_REDONDEO_RT b
  ON p.CodArtigo = b.CodArtigo 
  AND p.IdTipoDebCred = b.IdTipoDebCred
WHERE p.IdTipoDebCred = 52;

UPDATE cm.PDVITEM
SET Preco = b.Preco
FROM cm.PDVITEM p
JOIN cm.PDVITEM_BACKUP_REDONDEO_ROM b
  ON p.CodArtigo = b.CodArtigo 
  AND p.IdTipoDebCred = b.IdTipoDebCred
WHERE p.IdTipoDebCred = 56;

*/