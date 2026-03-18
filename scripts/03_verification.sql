/*
================================================================================
POST-UPDATE VERIFICATION QUERIES
================================================================================
System: SQL Server 2014 / TOTVS
Purpose: Validate that price update executed correctly
================================================================================
*/

-- Bidirectional EXCEPT verification - RT
SELECT COUNT(*) as ModifiedRecords_RT
FROM (
    SELECT * FROM cm.PDVITEM WHERE IdTipoDebCred = 52
    EXCEPT 
    SELECT * FROM cm.PDVITEM_BACKUP_REDONDEO_RT
) changes;

SELECT COUNT(*) as DeletedRecords_RT
FROM (
    SELECT * FROM cm.PDVITEM_BACKUP_REDONDEO_RT
    EXCEPT 
    SELECT * FROM cm.PDVITEM WHERE IdTipoDebCred = 52
) deleted;

-- Bidirectional EXCEPT verification - ROM
SELECT COUNT(*) as ModifiedRecords_ROM
FROM (
    SELECT * FROM cm.PDVITEM WHERE IdTipoDebCred = 56
    EXCEPT 
    SELECT * FROM cm.PDVITEM_BACKUP_REDONDEO_ROM
) changes;

SELECT COUNT(*) as DeletedRecords_ROM
FROM (
    SELECT * FROM cm.PDVITEM_BACKUP_REDONDEO_ROM
    EXCEPT 
    SELECT * FROM cm.PDVITEM WHERE IdTipoDebCred = 56
) deleted;

-- Change details - RT
SELECT 
    b.CodArtigo,
    pr.DescProd,
    b.Preco as PreviousPrice,
    a.Preco as NewPrice,
    a.Preco - b.Preco as Difference
FROM cm.PDVITEM_BACKUP_REDONDEO_RT b
JOIN cm.PDVITEM a ON a.CodArtigo = b.CodArtigo AND a.IdTipoDebCred = b.IdTipoDebCred
LEFT JOIN cm.PRODUTO pr ON b.CodArtigo = pr.CodProduto
WHERE b.Preco != a.Preco
ORDER BY ABS(a.Preco - b.Preco) DESC;

-- Change details - ROM
SELECT 
    b.CodArtigo,
    pr.DescProd,
    b.Preco as PreviousPrice,
    a.Preco as NewPrice,
    a.Preco - b.Preco as Difference
FROM cm.PDVITEM_BACKUP_REDONDEO_ROM b
JOIN cm.PDVITEM a ON a.CodArtigo = b.CodArtigo AND a.IdTipoDebCred = b.IdTipoDebCred
LEFT JOIN cm.PRODUTO pr ON b.CodArtigo = pr.CodProduto
WHERE b.Preco != a.Preco
ORDER BY ABS(a.Preco - b.Preco) DESC;

-- Verify symbolic items (0.01) were not modified
SELECT COUNT(*) as IntactSymbolicItems
FROM cm.PDVITEM
WHERE IdTipoDebCred IN (52, 56)
  AND Preco = 0.01;