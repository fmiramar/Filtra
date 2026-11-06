#include "MS20SK.hpp"
#include "MS20TPT.hpp"
#include "MS20Diode.hpp"
#include "MS20OTA.hpp"
#include "MS20Circuit.hpp"
#include "FSWasp.hpp"
#include "FSSteiner.hpp"
#include "FSPolivoks.hpp"
#include "FSZMorph.hpp"

static InterfaceTable* ft;

PluginLoad(MS20Filters) {
    ft = inTable;
    (*ft->fDefineUnit)("MS20SK", sizeof(ms20::MS20SK), (UnitCtorFunc)&ms20::MS20SK_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20TPT", sizeof(ms20::MS20TPT), (UnitCtorFunc)&ms20::MS20TPT_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20Diode", sizeof(ms20::MS20Diode), (UnitCtorFunc)&ms20::MS20Diode_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20OTA", sizeof(ms20::MS20OTA), (UnitCtorFunc)&ms20::MS20OTA_Ctor, 0, 0);
    (*ft->fDefineUnit)("MS20Circuit", sizeof(ms20::MS20Circuit), (UnitCtorFunc)&ms20::MS20Circuit_Ctor, 0, 0);
    (*ft->fDefineUnit)("FSWasp", sizeof(fs::FSWasp), (UnitCtorFunc)&fs::FSWasp_Ctor, 0, 0);
    (*ft->fDefineUnit)("FSSteiner", sizeof(fs::FSSteiner), (UnitCtorFunc)&fs::FSSteiner_Ctor, 0, 0);
    (*ft->fDefineUnit)("FSPolivoks", sizeof(fs::FSPolivoks), (UnitCtorFunc)&fs::FSPolivoks_Ctor, 0, 0);
    (*ft->fDefineUnit)("FSZMorph", sizeof(fs::FSZMorph), (UnitCtorFunc)&fs::FSZMorph_Ctor, 0, 0);
}
