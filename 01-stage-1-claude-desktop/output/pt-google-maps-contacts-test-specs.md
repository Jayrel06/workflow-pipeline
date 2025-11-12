# PT Google Maps Contact Scraper - Test Specs (Streamlined)

## Critical Test Cases

### 1. Happy Path - New City
**Input**: Phoenix, AZ, limit: 20
**Expected**: 15-20 clinics inserted, <5 duplicates
**Validation**: Check Postgres for new records with Phoenix, AZ

### 2. Duplicate Detection
**Setup**: Run Phoenix twice
**Expected**: Second run finds ~90% duplicates, only 1-2 new inserts
**Validation**: No duplicate phone numbers in database

### 3. Missing Data Handling
**Scenario**: Clinic has no website or phone listed
**Expected**: Record still inserted with NULL values
**Validation**: Partial data stored, not rejected

### 4. Non-PT Business Filtered
**Scenario**: Scrape includes chiropractor or massage
**Expected**: Filtered out, not stored
**Validation**: Only PT-related businesses in database

### 5. Google CAPTCHA
**Scenario**: Google shows CAPTCHA
**Expected**: Workflow pauses, alert sent, waits for manual solve
**Validation**: Workflow can resume after CAPTCHA cleared

---

## Database Setup
```sql
TRUNCATE TABLE clinics_contact_info RESTART IDENTITY;
-- Ready for testing
```

## Success Criteria
- ✅ 80% of clinics have phone OR website
- ✅ <5% non-PT businesses slip through
- ✅ <2% duplicate rate across runs
- ✅ Execution time <15 minutes per 100 clinics
