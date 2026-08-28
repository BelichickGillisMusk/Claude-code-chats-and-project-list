# Rent Roll Shell — rent-ruby.com

A clean, customizable rent roll component. Unit 105 is pinned to the top as the example/owner unit.

## What it looks like

```
┌─────────────────────────────────────────────────┐
│  Rent Roll                   August 2026         │
│                                                  │
│  [6 Units]  [$10,125 Collected]  [$3,037 Owed]  │
│                                                  │
│  [All] [Paid] [Late] [Partial] [Vacant]          │
│                                                  │
│  🟠 105  Bryan Gillis      $2,200  ✅ Paid        │
│     101  Maria Santos      $1,950  ✅ Paid        │
│     102  James Okafor      $2,100  🔴 Late -$2,100│
│     103  VACANT            $2,050  ⬜ Vacant      │
│     104  Priya Nair        $1,875  🟡 Partial     │
│     106  Devon Clark       $2,300  ✅ Paid        │
└─────────────────────────────────────────────────┘
```

Click any row to expand and see lease dates, balance, and notes.

## How to use this in RENT-DMC

1. Copy `RentRoll.tsx` into `RENT-DMC/src/components/`
2. Import it wherever you want:
   ```tsx
   import RentRoll from './components/RentRoll';
   // then use: <RentRoll />
   ```
3. Edit the `UNITS` array at the top of the file with your real data.

## Customize the data

Each unit has these fields — change them to match your building:

| Field | Example | What it is |
|---|---|---|
| `unit` | `"105"` | Unit number (string) |
| `tenant` | `"Bryan Gillis"` | Tenant full name, or `"VACANT"` |
| `monthlyRent` | `2200` | Monthly rent in dollars |
| `balance` | `0` | Amount still owed (0 = fully paid) |
| `status` | `"paid"` | One of: `paid`, `late`, `partial`, `vacant` |
| `leaseStart` | `"2024-09-01"` | Lease start date (YYYY-MM-DD) |
| `leaseEnd` | `"2025-08-31"` | Lease end date (YYYY-MM-DD) |
| `notes` | `"Owner unit"` | Any notes you want visible in the expanded row |

## Add more units

Just add more objects to the `UNITS` array:
```tsx
{
  unit: '107',
  tenant: 'New Tenant Name',
  monthlyRent: 2400,
  balance: 0,
  status: 'paid',
  leaseStart: '2025-01-01',
  leaseEnd: '2025-12-31',
  notes: '',
},
```

## Dependencies needed
```bash
npm install lucide-react
```
Tailwind CSS must already be set up (it is in RENT-DMC).
