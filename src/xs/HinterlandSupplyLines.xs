// Flat entry point at the xs root. The RMS uses `#includeXS HinterlandSupplyLines.xs`
// and the scenario uses Script Filename = HinterlandSupplyLines, so neither depends
// on subfolder support in #includeXS (unverified). Subfolder includes below use the
// XS `include` statement, which is known to work.
include "Hinterland\main.xs";
