# SmartCare GlobalCodes — Category + GlobalCodeId

Any picklist FK (`type_GlobalCode`) must use the **exact Category** and **`GlobalCodeId`**.

## Lookup (read-only)

```sql
SELECT GlobalCodeId, Code, CodeName, Category, Active
FROM dbo.GlobalCodes
WHERE RTRIM(LTRIM(Category)) = N'<CATEGORY>'
  AND Active = N'Y'
  AND ISNULL(RecordDeleted, N'N') = N'N';
```

Match **CodeName** → **GlobalCodeId**. Confirm Category is exact (`RACE`, not `LIKE '%RACE%'`).

## Do not

| Wrong | Why |
|-------|-----|
| Write **`Code`** as the FK | The same Code number can mean different GlobalCodeIds in other categories |
| `Category LIKE '%RACE%'` | Hits many race-related categories |
| Guess ids from another category | Same CodeName can exist in many categories |

## Exceptions

- **`Clients.Sex`**: often `M`/`F` as `type_Sex` — join SEX by **Code** when that is the product contract
- **DFA radios ItemType 5365**: often persist **`ExternalCode1`**, not GlobalCodeId
