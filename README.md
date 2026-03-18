# Hotel ERP Price Automation with SQL

## 📋 Executive Summary

Automation of the price update process in a hotel ERP system (TOTVS), enabling a previously unusable system feature and reducing update time from 2+ hours to 5 minutes.

**Impact:**
- ⏱️ **96% time reduction** (120+ min → 5 min)
- ✅ **Complete elimination of manual transcription errors**
- 🔓 **Enabled previously unusable system functionality**
- 📚 **Documented and transferable process**

---

## 🎯 Context and Problem

### Initial Situation

A boutique hotel uses the TOTVS ERP system to manage its Point of Sale (POS) operations. Monthly price updates were completely manual due to a technical system limitation.

**The technical problem:**
The system includes a "Percentage Update" function that should allow applying increases (e.g., +16%) to all items simultaneously. However, this function **does not include rounding**, generating prices with impractical decimals:
```
Example:
Original price: $3,200
16% increase: $3,712.00  ← Problem: impractical decimals for cash operations
Desired price: $3,700 or $3,500  ← Needed to facilitate change-making
```

**Consequence:** The percentage update function **was never used**, forcing a completely manual process.

### Manual Process (BEFORE)

1. Calculate new prices in Excel (formula: `previous_price × 1.16`)
2. Open the ERP system
3. **Item by item** (82 items):
   - Open product record
   - Copy price from Excel
   - Paste into system
   - Save
4. Export prices from Restaurant POS
5. Import into Room Service POS
6. Adjust 2 items that differ between POSs

**Total time:** 2+ hours per monthly update  
**Error rate:** 3-5 transcription errors per month  
**Dependency:** Only 1 person knew the process

---

## 💡 Implemented Solution

### Approach

Instead of avoiding the system functionality, I developed a process that **enables** it:

1. **Database analysis** to understand structure without official documentation
2. **Automatic SQL rounding script** post-update
3. **Validated process** with backups and verifications
4. **Complete documentation** for autonomous operation

### Technical Architecture

**System:** SQL Server 2014  
**Main tables:**
```
cm.PDVITEM
├─ CodArtigo (Product ID)
├─ IdTipoDebCred (POS ID)
└─ Preco (NUMERIC(12,2) - price)

cm.PRODUTO
└─ DescProd (product description)
```

**Managed POSs:**
- Restaurant (ID: 52)
- Room Service (ID: 56) - identical prices to Restaurant
- Others: Laundry, Minibar, Terraces, etc.

### Key Technical Findings

During analysis, I discovered critical system aspects:

1. **Automatic protection of symbolic prices**
   - Items priced at $0.01 (placeholders) are automatically preserved
   - Data type `NUMERIC(12,2)` truncates decimals: 0.01 × 1.16 = 0.0116 → 0.01

2. **Record duplication RT/ROM**
   - Same product exists in two rows (one per POS)
   - Allows simultaneous update with a single operation

3. **Absence of triggers**
   - Verified with `sys.triggers`
   - Direct update is safe

### Automated Process (AFTER)

1. Use system's "Update by %" function (2 min)
2. Execute SQL rounding script (30 sec)
3. Verify changes automatically (1 min)
4. Import to Room Service (2 min)

**Total time:** ~5 minutes  
**Errors:** 0  
**Operator:** Anyone with the guide

---

## 🔧 Technical Implementation

### Phase 1: Research (3 days)

Without official system documentation, I performed database reverse engineering:
```sql
-- Identify relevant tables
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'cm' AND TABLE_NAME LIKE '%PDV%';

-- Analyze relationships
SELECT OBJECT_NAME(parent_object_id) AS ReferencingTable,
       name AS FKName
FROM sys.foreign_keys 
WHERE referenced_object_id = OBJECT_ID('cm.PDVITEM');

-- Verify triggers (critical for safety validation)
SELECT name, type_desc 
FROM sys.triggers 
WHERE parent_id = OBJECT_ID('cm.PDVITEM');
```

**Result:** 11 related tables, no triggers, history in PDVALTPRECO

### Phase 2: Development (2 days)

SQL script components:

1. **Preview without execution** - visualize changes before applying
2. **Automatic backup** - backup per POS before modifying
3. **Update with rounding logic** - configurable multiples (200, 500, 1000)
4. **Bidirectional verification** - validate integrity with EXCEPT
5. **Rollback** - revert in case of error

**Rounding logic example:**
```sql
UPDATE cm.PDVITEM 
SET Preco = CASE 
    WHEN Preco < 2 THEN Preco  -- Protect symbolic prices
    ELSE ROUND(Preco / 200.0, 0) * 200  -- Round to multiple of 200
END
WHERE IdTipoDebCred IN (52, 56)  -- RT and ROM simultaneously
  AND Preco >= 2;
```

### Phase 3: Validation (1 day)

Cascading test protocol:

1. ✅ Test with 3 items in development environment
2. ✅ Manual verification in system interface
3. ✅ Complete rollback and verification
4. ✅ Pilot execution with 10 items in production
5. ✅ Full execution outside operating hours

### Phase 4: Documentation (1 day)

Creation of 200+ line operational guide with:
- Step-by-step process with ready-to-copy SQL commands
- Execution checklist
- Common error handling
- Change log template

---

## 📊 Results and Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Execution time** | 120+ min | 5 min | **96% ↓** |
| **Manual operations** | 82 items | 0 | **100% ↓** |
| **Errors per update** | 3-5 | 0 | **100% ↓** |
| **Trained personnel** | 1 | Anyone with guide | ✅ |
| **Traceability** | None | Backups + SQL logs | ✅ |
| **System function usable** | No | Yes | ✅ |

### Business Value

- **Immediate ROI:** 2+ hours saved per month × 12 months = 24+ hours/year
- **Risk reduction:** Elimination of transcription errors
- **Scalability:** Process applicable to other POSs (Laundry, Minibar, etc.)
- **Knowledge transfer:** 3 people trained in 6 months

---

## 🛠️ Tech Stack

- **Database:** SQL Server 2014
- **Tool:** SQL Server Management Studio
- **ERP System:** TOTVS (Ex CM Soluções Informáticas)
- **Language:** T-SQL

---

## 📁 Repository Structure
```
.
├── README.md                       # This file
├── docs/
│   └── operational_guide.txt      # Complete step-by-step guide
└── scripts/
    ├── 01_exploration.sql         # Initial research queries
    ├── 02_price_update.sql        # Main rounding script
    └── 03_verification.sql        # Validation and audit
```

---

## 🎓 Skills Demonstrated

### Technical
- Database reverse engineering without documentation
- Legacy system analysis (TOTVS)
- SQL script development with error handling
- Process design with rollback and audit
- Query optimization (EXCEPT, CASE, JOIN)

### Business
- Operational inefficiency identification
- Impact quantification (time, errors, ROI)
- Risk management (backups, incremental testing)
- Documentation for non-technical users
- Effective knowledge transfer

### Methodology
- Iterative approach: research → development → testing → documentation
- Layered validation: preview → partial test → production
- Documentation as key deliverable
- Maintainability-oriented design

---

## 🚀 Project Evolution

### Current Phase (Completed)
✅ Price rounding automation via SQL  
✅ Complete operational documentation  
✅ 3 people trained in process usage

### Next Steps Planned:
🔄 - Complete automation with Python
   - Automatic generation of printed menu (Word) from Excel
   - Integration of complete flow: Excel → SQL → Word

💡  Control dashboard
   - Visualization of price change history
   - POS inconsistency alerts
   - Update metrics

---

## 📄 Data Privacy Note

All sensitive data (establishment name, location, customer data) has been anonymized. This project is presented for professional portfolio purposes.

---

## 👤 Contact

Developed as part of my experience in operations analysis and process optimization.

**LinkedIn:** [Linkedin](https://www.linkedin.com/in/jplarussa/)  
**Portfolio:** [Github portfolio](https://github.com/jplarussa)

---

*Project documented in January 2026*
