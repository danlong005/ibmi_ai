# UUID / Identity ID / Owner ID — Table Reference

**Date:** 2026-03-04
**Author:** D. Long

---

## Overview

This document catalogues every table in the production source that stores a UUID, identity ID, owner ID, or member/associate number, and describes how data flows into each table.

---

## Tables

### 1. ADONXREF — Primary UUID Cross-Reference

**Source:** `adonxref.sql`

The central cross-reference table that maps Adonis UUIDs to member and associate numbers.

| Field | Type | Description |
|-------|------|-------------|
| `UUID` | CHAR(36) | Adonis UUID |
| `MBRASCNO` | DEC(11,0) | Member or Associate number |
| `MBRASCIND` | CHAR(1) | `M` = Member, `A` = Associate |
| `UUIDCLSC` | CHAR(16) | Classic UUID |
| `ROW_ID` | DEC(13,0) | Auto-generated identity |
| `CREATED_AT` | TIMESTAMP | Row creation timestamp |
| `CHANGED_AT` | TIMESTAMP | Last change timestamp |

**Indexes:**
- `ADONXREF01` — (MBRASCNO, MBRASCIND)
- `ADONXREF02` — (UUIDCLSC, MBRASCIND)
- `ADONXREF03` — (UUID, MBRASCIND)
- `ADONXREF04` — (UUIDCLSC)
- `ADONXREF05` — (UUID)
- `ADONXREF06` — (MBRASCIND, MBRASCNO, UUIDCLSC, UUID)
- `ADONXREF11` — (MBRASCNO, UUID)

**How data is created:**

1. **Trigger `BILFILTRG3`** (`bilfiltrg3.sql`) — fires AFTER INSERT or UPDATE OF `PPCNYY` on `BILFILEP`. It checks if the member already exists in `ADONXREF`; if not, it pulls the UUID from `AHAPPSP.AHNADNUUID` and inserts:
   ```sql
   INSERT INTO ADONXREF (UUID, MBRASCNO, MBRASCIND)
     VALUES (@UUID, n.pppol, 'M');
   ```

2. **Trigger `TVCAGTTRG1`** (`tvcagttrg1.sql`) — fires AFTER INSERT on `TVCAGTP`. It checks if the associate already exists in `ADONXREF`; if not, it pulls the UUID from `AHASSOCP.TVHADNUUID` and inserts:
   ```sql
   INSERT INTO ADONXREF (UUID, MBRASCNO, MBRASCIND)
     VALUES (@UUID, n.tvcagt, 'A');
   ```

3. **Sync process** (`sync.sqlrpgle` / `SYNCPRC25T.TXT`) — bulk-syncs rows from the production database using `INSERT INTO ADONXREF OVERRIDING USER VALUE`.

**Audit:** Trigger `ADONXRTRGA` (`adonxrtrga.sqlrpgle`) fires on INSERT/UPDATE/DELETE and writes before/after images to `ATLASEVSYN` for event synchronization.

---

### 2. ADONXREFU — Sync Temp Table

**Source:** `adonxrefu.sql`

Staging table used during sync processing.

| Field | Type | Description |
|-------|------|-------------|
| `UUID` | CHAR(36) | Adonis UUID |
| `MBRASCNO` | DEC(11,0) | Member/Associate number |
| `MBRASCIND` | CHAR(1) | `M` or `A` |
| `FLAG` | CHAR(20) | Processing flag |
| `FLAG2` | CHAR(20) | Processing flag 2 |
| `UUIDCLSC` | CHAR(16) | Classic UUID |

**How data is created:** Populated during sync batch processing as a working copy before merging into `ADONXREF`.

---

### 3. AHAPPSP — Web/Phone Membership Applications

**Source:** `ahappsp.pf`

Holds application records for new memberships submitted online or by phone. Contains the Adonis UUID assigned at application time.

| Field | Type | Description |
|-------|------|-------------|
| `AHNPOL` | DEC(11,0) | Member/Policy number |
| `AHNADNUUID` | CHAR(36) | Adonis UUID |

**Indexes:**
- `AHAPPS69` — (AHNADNUUID)
- `AHAPPS70` — (AHNPOL, AHNADNUUID)

**How data is created:** Written during application intake processing. The UUID is assigned by the upstream web/phone enrollment system and stored with the application record. This table acts as the **source of truth** for the UUID that later gets copied into `ADONXREF` by the `BILFILTRG3` trigger.

---

### 4. AHASSOCP — Associate Hold File

**Source:** `ahassocp.pf`

Holds associate enrollment records with their assigned Adonis UUID.

| Field | Type | Description |
|-------|------|-------------|
| `TVHAGT` | DEC(9,0) | Associate number |
| `TVHADNUUID` | CHAR(36) | Adonis UUID |

**How data is created:** Written during associate enrollment. The UUID is assigned upstream and stored here. This table is the **source of truth** for associate UUIDs that get copied into `ADONXREF` by the `TVCAGTTRG1` trigger.

---

### 5. BIUINDIV — Unique Individual Member Table

**Source:** `biuindiv.sql`

Maps a single individual across multiple product-line member numbers.

| Field | Type | Description |
|-------|------|-------------|
| `UUID` | DEC(17,0) | Auto-generated unique individual ID (IDENTITY) |
| `BIUILSNO` | DEC(11,0) | LS member number |
| `BIUIIDTNO` | DEC(11,0) | IDT member number |
| `BIUIBUSNO` | DEC(11,0) | BUS member number |
| `BIUICDLNO` | DEC(11,0) | CDL member number |
| `BIUILSENO` | DEC(11,0) | LSE member number |
| `BIUIOTHNO` | DEC(11,0) | Other member number |
| `BIUIERRNO` | DEC(11,0) | Error member number |

**Primary Key:** UUID

**How data is created:** The `UUID` is system-generated (IDENTITY column). Rows are inserted when linking member numbers across product lines.

---

### 6. DPPFMSTR — Dependent/Family Master File

**Source:** `dppfmstr.pf`

Stores dependent records for each member, with UUID fields to track the dependent's identity.

| Field | Type | Description |
|-------|------|-------------|
| `DPPOL` | DEC(11,0) | Member/Policy number |
| `DPCPID` | CHAR(16) | Dependent CPID (identity ID) |
| `DPCLSCUUID` | CHAR(16) | Classic UUID |

**Indexes:**
- `DPPFMSTR01` — (DPBDMO, DPBDDA, DPBDYR, DPCPID)
- `DPPFMSTR09` — (DPCLSCUUID)
- `DPPFMSTR10` — (DPPOL, DPCLSCUUID)
- `DPPFMSTR12` — (DPREL, DPCLSCUUID)
- `DPPFMSTR13` — (DPREL, DPCPID)
- `DPPFMSTR23` — (DPPOL, DPCPID)
- `DPPFMSTR24` — (DPCPID, DPPOL)

**How data is created:** Program `DEP0036R` (`dep0036r.sqlrpgle`) inserts and updates dependent records:
```sql
INSERT INTO DPPFMSTR
  (dpstat, dpcomp, ..., dpcpid, datstamp, dauser, dapgm, dauuid, daclscuuid)
  VALUES (...);
```
The `DPCPID` and `DPCLSCUUID` values come from the dependent identity lookup performed earlier in the program.

---

### 7. DPNDACT — Dependent Activity Log

**Source:** Referenced in `dep0036r.sqlrpgle`

Audit/activity table that logs every add, change, or delete action on a dependent record.

| Field | Type | Description |
|-------|------|-------------|
| `DAPOL` | DEC(11,0) | Member/Policy number |
| `DAUUID` | CHAR(16) | UUID (from DPCPID) |
| `DACLSCUUID` | CHAR(16) | Classic UUID |
| `DAACTION` | CHAR | Action type |
| `DATSTAMP` | TIMESTAMP | Timestamp |

**How data is created:** `DEP0036R` inserts activity records whenever a dependent is added, changed, or deleted:
```sql
INSERT INTO DPNDACT
  (dapol, dadeplname, dadepfname, darel, daefdate, daaction,
   datstamp, dauser, dapgm, dauuid, daclscuuid)
  VALUES (...);
```

---

## Service Programs That Use Identity/Owner ID

### OWNERID — Owner Identity Service

**Source:** `ownerid.sqlrpgle`

| Procedure | Description |
|-----------|-------------|
| `OWNERID_GET_IDENTITY` | Retrieves identity/owner ID by member number |
| `GET_IDS_PROVIDER` | Gets entitlements for a member |
| `OWNERID_AUDITOR_IDS` | Gets auditor IDs |

Accepts a member number (`VARCHAR(11)`) and calls external identity APIs to resolve the owner ID / identity ID.

### PMTSVC — Payment Service

**Source:** `pmtsvc.sqlrpgle`

| Procedure | Key Parameter | Description |
|-----------|--------------|-------------|
| `PMTSVC_CreatePaymentMethod` | `ownerId VARCHAR(36)` | Creates a payment method using the owner's identity ID |
| `PMTSVC_GetPaymentMethodsByOwnerId` | `ownerIdentity VARCHAR(36)` | Retrieves payment methods by owner/identity ID |

Builds API URLs substituting `<ownerId>` and `<identityId>` placeholders with the passed-in identity values.

### MBRMGR — Member Manager Service

**Source:** `mbrmgr.sqlrpgle` (in working branch)

| Procedure | Description |
|-----------|-------------|
| `MBRMGR_GetIdentityByFriendlyId` | Calls the members-migration API to get `ownerId` by member number |

Returns `MBRMGR_ResultDS` containing `ownerId`, `subscriptionId`, `entitlementId`, `riskLevel`, `riskStatus`.

---

## Data Flow Summary

```
Enrollment (Web/Phone)
  |
  v
AHAPPSP (members)          AHASSOCP (associates)
  |  UUID assigned             |  UUID assigned
  |                            |
  v                            v
BILFILTRG3 trigger          TVCAGTTRG1 trigger
  |                            |
  +----------------------------+
  |
  v
ADONXREF (central cross-reference: UUID <-> Member/Associate #)
  |
  v
ADONXRTRGA trigger -> ATLASEVSYN (audit/sync events)

Dependent Maintenance (DEP0036R)
  |
  v
DPPFMSTR (dependent identity: DPCPID, DPCLSCUUID)
  |
  v
DPNDACT (activity log with UUID)

Identity Resolution (runtime)
  OWNERID  -> external API -> owner ID / identity ID
  PMTSVC   -> uses owner ID for payment API calls
  MBRMGR   -> uses member # to get owner ID from members-migration API
```
