#include "MS20SK.hpp"
#include "MS20TPT.hpp"
#include "MS20Diode.hpp"
#include "MS20OTA.hpp"
#include "MS20Circuit.hpp"
#include "Wasp.hpp"
#include "Steiner.hpp"
#include "Polivoks.hpp"
#include "ZMorph.hpp"
#include "Dispersion.hpp"

static InterfaceTable* ft;

PluginLoad(MS20Filters) {
    ft = inTable;
    (*ft->fDefineUnit)("MS20SK", sizeof(ms20::MS20SK), (UnitCtorFunc)&ms20::MS20SK_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20TPT", sizeof(ms20::MS20TPT), (UnitCtorFunc)&ms20::MS20TPT_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20Diode", sizeof(ms20::MS20Diode), (UnitCtorFunc)&ms20::MS20Diode_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20OTA", sizeof(ms20::MS20OTA), (UnitCtorFunc)&ms20::MS20OTA_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20Circuit", sizeof(ms20::MS20Circuit), (UnitCtorFunc)&ms20::MS20Circuit_Ctor, 0, 0);

    // Primary filter names
    (*ft->fDefineUnit)("Wasp", sizeof(fs::Wasp), (UnitCtorFunc)&fs::Wasp_Ctor, 0, 0);
    (*ft->fDefineUnit)("Steiner", sizeof(fs::Steiner), (UnitCtorFunc)&fs::Steiner_Ctor, 0, 0);
    (*ft->fDefineUnit)("Polivoks", sizeof(fs::Polivoks), (UnitCtorFunc)&fs::Polivoks_Ctor, 0, 0);
    (*ft->fDefineUnit)("ZMorph", sizeof(fs::ZMorph), (UnitCtorFunc)&fs::ZMorph_Ctor, 0, 0);
    (*ft->fDefineUnit)("Dispersion", sizeof(fs::Dispersion), (UnitCtorFunc)&fs::Dispersion_Ctor, 0, 0);
}
