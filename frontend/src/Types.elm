module Types exposing (..)

import Http
import Loading exposing (Loading(..))

import Generated.Types exposing (..)

import UI.Tabs as Tabs
import UI.Slider as Slider
import Time
import Dict exposing (Dict)
import Set exposing (Set)
import Set.Any exposing (AnySet)

import Bootstrap.Dropdown  as Dropdown


type Var = VarBinder Binder
         | VarTop TopBindingInfo
         | VarExternal ExternalName


type alias PhaseId = Int
type alias TabId = Int
type alias Slug = String
type alias ModuleName = String

type alias CodeTabModule =
    { mod : Loading Module
    , projectMeta : Capture
    , phaseSlider : Slider.Model
    , topNames : List TopBindingInfo
    }

type alias CodeTab = 
    { id : TabId
    , name : String
    , modules : Dict Slug CodeTabModule
    , currentModule : ModuleName
    , moduleDropdown : Dropdown.State
    , selectedVar : Maybe Var
    , hideTypes : Bool
    , disambiguateVariables : Bool
    , showRecursiveGroups : Bool 
    }

type CodeTabMsg
    = CodeMsgSetModule ModuleName Int
    | CodeMsgGotModule Slug (Result Http.Error Module)
    | CodeMsgSelectVar Var
    | CodeMsgToggleHideTypes
    | CodeMsgToggleDisambiguateVariables
    | CodeMsgToggleShowRecursiveGroups
    | CodeMsgModuleDropdown Dropdown.State
    | CodeMsgSlider Slug Slider.Msg
    

type alias Model = 
    { pageTab : Tabs.Model
    , capturesLoading : Loading (List Capture)
    , timezone : Time.Zone
    , codeTabs : Dict TabId CodeTab
    , overviewTab : OverviewTab
    , idGen : Int
    }

type alias OverviewTab =
    { enabledProjects : AnySet Slug Capture
    }

type OverviewMsg
    = OverviewMsgToggleProject Capture


type Msg 
    = MsgGotCaptures (Result Http.Error (List Capture))
    | MsgCodeMsg TabId CodeTabMsg
    | MsgPageTab Tabs.Msg
    | MsgOverViewTab OverviewMsg
    | MsgOpenCodeTab
    | MsgAdjustTimeZone Time.Zone
