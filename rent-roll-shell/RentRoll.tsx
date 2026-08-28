/**
 * RentRoll.tsx — Clean shell component for rent-ruby.com
 *
 * HOW TO USE:
 * - Replace the UNITS array below with your real units (or load from an API/database).
 * - Each unit row shows: unit #, tenant name, monthly rent, status, lease dates, balance owed.
 * - The summary bar at the top auto-calculates totals from the UNITS array.
 * - Styling uses plain Tailwind CSS classes — swap colors to match your brand.
 *
 * DEPENDENCIES (already in RENT-DMC):
 *   npm install lucide-react
 *   (Tailwind CSS must be configured)
 */

import React, { useState } from 'react';
import {
  Building2,
  DollarSign,
  AlertCircle,
  CheckCircle2,
  Clock,
  ChevronDown,
  ChevronUp,
  FileText,
} from 'lucide-react';

// ─────────────────────────────────────────────
// TYPES — edit fields here if you need more/less
// ─────────────────────────────────────────────
type RentStatus = 'paid' | 'late' | 'partial' | 'vacant';

interface Unit {
  unit: string;         // e.g. "105"
  tenant: string;       // full name, or "VACANT"
  monthlyRent: number;  // in dollars, e.g. 2200
  balance: number;      // amount owed (0 if fully paid)
  status: RentStatus;
  leaseStart: string;   // "YYYY-MM-DD"
  leaseEnd: string;     // "YYYY-MM-DD"
  notes: string;        // any free-text note for this unit
}

// ─────────────────────────────────────────────
// DATA — replace with your real units
// Unit 105 is your unit, shown first as the example
// ─────────────────────────────────────────────
const UNITS: Unit[] = [
  {
    unit: '105',
    tenant: 'Bryan Gillis',        // ← your unit
    monthlyRent: 2200,
    balance: 0,
    status: 'paid',
    leaseStart: '2024-09-01',
    leaseEnd: '2025-08-31',
    notes: 'Owner unit — management office.',
  },
  {
    unit: '101',
    tenant: 'Maria Santos',
    monthlyRent: 1950,
    balance: 0,
    status: 'paid',
    leaseStart: '2024-03-01',
    leaseEnd: '2025-02-28',
    notes: '',
  },
  {
    unit: '102',
    tenant: 'James Okafor',
    monthlyRent: 2100,
    balance: 2100,
    status: 'late',
    leaseStart: '2023-11-01',
    leaseEnd: '2024-10-31',
    notes: 'Called 8/26 — says will pay by 9/1.',
  },
  {
    unit: '103',
    tenant: 'VACANT',
    monthlyRent: 2050,
    balance: 0,
    status: 'vacant',
    leaseStart: '',
    leaseEnd: '',
    notes: 'Turnover in progress. Available 9/15.',
  },
  {
    unit: '104',
    tenant: 'Priya Nair',
    monthlyRent: 1875,
    balance: 937,
    status: 'partial',
    leaseStart: '2024-01-01',
    leaseEnd: '2024-12-31',
    notes: 'Partial payment received 8/5.',
  },
  {
    unit: '106',
    tenant: 'Devon Clark',
    monthlyRent: 2300,
    balance: 0,
    status: 'paid',
    leaseStart: '2024-06-01',
    leaseEnd: '2025-05-31',
    notes: '',
  },
];

// ─────────────────────────────────────────────
// STATUS HELPERS
// ─────────────────────────────────────────────
const STATUS_CONFIG: Record<RentStatus, { label: string; color: string; icon: React.ReactNode }> = {
  paid:    { label: 'Paid',    color: 'bg-green-100 text-green-800',  icon: <CheckCircle2 size={14} /> },
  late:    { label: 'Late',    color: 'bg-red-100 text-red-800',      icon: <AlertCircle size={14} /> },
  partial: { label: 'Partial', color: 'bg-yellow-100 text-yellow-800',icon: <Clock size={14} /> },
  vacant:  { label: 'Vacant',  color: 'bg-gray-100 text-gray-500',    icon: <Building2 size={14} /> },
};

function fmt(n: number) {
  return n.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
}

function fmtDate(d: string) {
  if (!d) return '—';
  const [y, m, day] = d.split('-');
  return `${m}/${day}/${y}`;
}

// ─────────────────────────────────────────────
// SUMMARY BAR (auto-calculated)
// ─────────────────────────────────────────────
function SummaryBar({ units }: { units: Unit[] }) {
  const occupied  = units.filter(u => u.status !== 'vacant').length;
  const total     = units.length;
  const collected = units.reduce((s, u) => s + (u.monthlyRent - u.balance), 0);
  const outstanding = units.reduce((s, u) => s + u.balance, 0);
  const occupancy = Math.round((occupied / total) * 100);

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      {/* Total units */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
        <Building2 className="text-orange-500" size={22} />
        <div>
          <p className="text-xs text-gray-500 uppercase tracking-wide">Units</p>
          <p className="text-2xl font-bold text-gray-900">{total}</p>
          <p className="text-xs text-gray-400">{occupied} occupied · {occupancy}%</p>
        </div>
      </div>

      {/* Collected */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
        <DollarSign className="text-green-500" size={22} />
        <div>
          <p className="text-xs text-gray-500 uppercase tracking-wide">Collected</p>
          <p className="text-2xl font-bold text-gray-900">{fmt(collected)}</p>
          <p className="text-xs text-gray-400">this month</p>
        </div>
      </div>

      {/* Outstanding */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
        <AlertCircle className="text-red-400" size={22} />
        <div>
          <p className="text-xs text-gray-500 uppercase tracking-wide">Outstanding</p>
          <p className="text-2xl font-bold text-gray-900">{fmt(outstanding)}</p>
          <p className="text-xs text-gray-400">unpaid balance</p>
        </div>
      </div>

      {/* Scheduled */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
        <FileText className="text-blue-400" size={22} />
        <div>
          <p className="text-xs text-gray-500 uppercase tracking-wide">Scheduled</p>
          <p className="text-2xl font-bold text-gray-900">
            {fmt(units.filter(u => u.status !== 'vacant').reduce((s, u) => s + u.monthlyRent, 0))}
          </p>
          <p className="text-xs text-gray-400">gross possible rent</p>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// UNIT ROW (expandable)
// ─────────────────────────────────────────────
function UnitRow({ unit, isHighlighted }: { unit: Unit; isHighlighted: boolean }) {
  const [open, setOpen] = useState(false);
  const cfg = STATUS_CONFIG[unit.status];

  return (
    <div
      className={`border rounded-xl mb-2 overflow-hidden transition-all
        ${isHighlighted ? 'border-orange-400 bg-orange-50' : 'border-gray-200 bg-white'}`}
    >
      {/* Main row */}
      <button
        className="w-full flex items-center gap-4 px-4 py-3 text-left"
        onClick={() => setOpen(o => !o)}
      >
        {/* Unit number */}
        <span
          className={`w-12 h-12 rounded-lg flex items-center justify-center font-bold text-lg flex-shrink-0
            ${isHighlighted ? 'bg-orange-500 text-white' : 'bg-gray-100 text-gray-700'}`}
        >
          {unit.unit}
        </span>

        {/* Tenant name */}
        <div className="flex-1 min-w-0">
          <p className={`font-semibold truncate ${unit.status === 'vacant' ? 'text-gray-400 italic' : 'text-gray-900'}`}>
            {unit.tenant}
          </p>
          {unit.status !== 'vacant' && (
            <p className="text-xs text-gray-400">
              Lease: {fmtDate(unit.leaseStart)} → {fmtDate(unit.leaseEnd)}
            </p>
          )}
        </div>

        {/* Rent amount */}
        <div className="text-right flex-shrink-0 hidden sm:block">
          <p className="font-bold text-gray-900">{fmt(unit.monthlyRent)}</p>
          <p className="text-xs text-gray-400">/ mo</p>
        </div>

        {/* Status badge */}
        <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold flex-shrink-0 ${cfg.color}`}>
          {cfg.icon}
          {cfg.label}
        </span>

        {/* Balance */}
        {unit.balance > 0 && (
          <span className="text-red-600 font-bold text-sm flex-shrink-0">
            -{fmt(unit.balance)}
          </span>
        )}

        {/* Expand toggle */}
        <span className="text-gray-400 flex-shrink-0">
          {open ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </span>
      </button>

      {/* Expanded detail */}
      {open && (
        <div className="px-4 pb-4 border-t border-gray-100 pt-3 grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
          <div>
            <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Monthly Rent</p>
            <p className="font-semibold">{fmt(unit.monthlyRent)}</p>
          </div>
          <div>
            <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Balance Owed</p>
            <p className={`font-semibold ${unit.balance > 0 ? 'text-red-600' : 'text-green-600'}`}>
              {unit.balance > 0 ? fmt(unit.balance) : 'None'}
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Lease Start</p>
            <p className="font-semibold">{fmtDate(unit.leaseStart)}</p>
          </div>
          <div>
            <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Lease End</p>
            <p className="font-semibold">{fmtDate(unit.leaseEnd)}</p>
          </div>
          {unit.notes && (
            <div className="col-span-2 md:col-span-4">
              <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Notes</p>
              <p className="text-gray-700 bg-gray-50 rounded-lg px-3 py-2">{unit.notes}</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────
// MAIN COMPONENT
// ─────────────────────────────────────────────
export default function RentRoll() {
  const [filter, setFilter] = useState<RentStatus | 'all'>('all');

  const filtered = filter === 'all'
    ? UNITS
    : UNITS.filter(u => u.status === filter);

  // Sort: your unit (105) always first, then by unit number
  const sorted = [...filtered].sort((a, b) => {
    if (a.unit === '105') return -1;
    if (b.unit === '105') return 1;
    return a.unit.localeCompare(b.unit);
  });

  return (
    <div className="min-h-screen bg-gray-50 p-4 md:p-8">
      <div className="max-w-4xl mx-auto">

        {/* Header */}
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900">Rent Roll</h1>
          <p className="text-gray-500 mt-1">
            {new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
          </p>
        </div>

        {/* Summary stats */}
        <SummaryBar units={UNITS} />

        {/* Filter tabs */}
        <div className="flex gap-2 mb-4 flex-wrap">
          {(['all', 'paid', 'late', 'partial', 'vacant'] as const).map(f => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors capitalize
                ${filter === f
                  ? 'bg-orange-500 text-white'
                  : 'bg-white border border-gray-200 text-gray-600 hover:border-orange-300'}`}
            >
              {f === 'all' ? 'All Units' : STATUS_CONFIG[f].label}
            </button>
          ))}
        </div>

        {/* Unit list */}
        {sorted.length === 0 ? (
          <p className="text-center text-gray-400 py-12">No units match this filter.</p>
        ) : (
          sorted.map(u => (
            <UnitRow key={u.unit} unit={u} isHighlighted={u.unit === '105'} />
          ))
        )}

        {/* Footer */}
        <p className="text-center text-xs text-gray-400 mt-8">
          rent-ruby.com · Owner dashboard · {new Date().getFullYear()}
        </p>
      </div>
    </div>
  );
}
