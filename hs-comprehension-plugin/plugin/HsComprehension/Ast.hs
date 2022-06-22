{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module HsComprehension.Ast 
    ( Capture (..)
    , ExternalName (..)
    , Binder (..)
    , IdInfo (..)
    , Unfolding (..)
    , Lit (..)
    , Type (..)
    , FiredRule (..)
    , Module (..)
    , Expr (..)
    , Alt (..)
    , AltCon (..)
    , TopBindingInfo (..)
    , TopBinding (..)
    -- re-export
    , Unique (..)
    , IdDetails (..)
    , BinderId (..)
    , TyCon (..)
    , SrcSpan (..)
    , LineCol (..)
    , OccInfo (..)
    , Tick (..)
    , CoreStats (..)
    , Rule(..)
    ) where

import GHC.Generics
import GHC.TypeLits (Symbol)

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.ByteString as BS
import Codec.Serialise (Serialise)

import GhcDump.Ast (Unique(..), IdDetails(..), TyCon(..), SrcSpan(..), LineCol(..), OccInfo(..), Tick(..), CoreStats(..))

data Capture = Capture 
    { captureName :: Text
    , captureDate :: Int
    , captureModules :: [(Text, Int)]
    }
    deriving (Generic, Serialise, Show)

data ExternalName = ExternalName
    { externalModuleName :: Text
    , externalName :: Text
    , externalUnique :: Unique
    , externalType :: Type
    }
    | ForeignCall
    deriving (Generic, Serialise, Show)

data BinderId = BinderId
    { binderIdUnique :: Unique
    , binderIdDeBruijn :: Int
    } deriving (Generic, Serialise, Show)

data Binder = Binder
    { binderName :: Text
    , binderId :: BinderId
    , binderIdInfo :: IdInfo
    , binderIdDetails :: IdDetails
    , binderType :: Type
    , binderSrcSpan :: SrcSpan
    , binderPhaseId :: Int
    } 
    |
    TyBinder { binderName :: Text
             , binderId :: BinderId
             , binderKind :: Type
             , binderPhaseId :: Int
             }

    deriving (Generic, Serialise, Show)

data IdInfo = IdInfo 
    { idiArity         :: !Int
    , idiIsOneShot     :: Bool
    , idiUnfolding     :: Unfolding
    , idiInlinePragma  :: !T.Text
    , idiOccInfo       :: OccInfo
    , idiStrictnessSig :: !T.Text
    , idiDemandSig     :: !T.Text
    , idiCallArity     :: !Int
    , idiRules         :: [Rule]
    }
    deriving (Generic, Serialise, Show)

data Unfolding
    = NoUnfolding
    | BootUnfolding
    | OtherCon [AltCon]
    | DFunUnfolding
    | CoreUnfolding { unfTemplate   :: Expr
                    , unfIsValue    :: Bool
                    , unfIsConLike  :: Bool
                    , unfIsWorkFree :: Bool
                    , unfGuidance   :: T.Text
                    }
    deriving (Generic, Serialise, Show)

data Lit 
    = MachChar Char
   | MachStr Text
   | MachNullAddr
   | MachInt Text
   | MachInt64 Text
   | MachWord Text
   | MachWord64 Text
   | MachFloat Text
   | MachDouble Text
   | MachLabel Text
   | LitInteger Text
   | LitNatural Text
   | LitRubbish
   deriving (Generic, Serialise, Show, Eq)

data Type
    = VarTy BinderId
    | FunTy Type Type
    | TyConApp TyCon [Type]
    | AppTy Type Type
    | ForAllTy Binder Type
    | LitTy
    | CoercionTy
    deriving (Generic, Serialise, Show)

data FiredRule = FiredRule
    { firedRuleName :: Text
    , firedRuleModule :: Text
    , firedRulePhase :: Int
    } deriving (Generic, Serialise, Show)

data Module = Module
    { moduleName :: Text
    , modulePhase :: Text
    , modulePhaseId :: Int
    , moduleTopBindings :: [TopBinding]
    , moduleRules :: [Rule]
    , moduleFiredRules :: [FiredRule]
    }
    deriving (Generic, Serialise, Show)

data Expr
    = EVar BinderId
    | EVarGlobal ExternalName
    | ELit Lit
    | EApp Expr Expr
    | ETyLam Binder Expr
    | ELam Binder Expr
    | ELet [(Binder, Expr)] Expr
    | ECase Expr Binder [Alt]
    | ETick Tick Expr
    | EType Type
    | ECoercion
    -- Marker tokens
    | EMarkDiff Expr
    deriving (Generic, Serialise, Show)

data Alt = Alt
    { altCon :: AltCon
    , altBinders :: [Binder]
    , altRHS :: Expr
    }
    deriving (Generic, Serialise, Show)

data AltCon 
    = AltDataCon !T.Text
    | AltLit Lit
    | AltDefault
    deriving (Generic, Serialise, Show)

data TopBindingInfo = TopBindingInfo
    { topBindingBinder :: Binder
    , topBindingCoreState :: CoreStats
    , topBindingRHS :: Expr
    , topBindingFromSource :: Bool
    , topBindingIdx :: Int
    }
    deriving (Generic, Serialise, Show)

data TopBinding
    = NonRecTopBinding TopBindingInfo
    | RecTopBinding [TopBindingInfo]
    deriving (Generic, Serialise, Show)

data Rule
    = Rule { ruleName :: T.Text
           , ruleBinders :: [Binder]
           , ruleRHS :: Expr
           , ruleAuto :: Bool
           }
    | BuiltinRule { ruleName :: T.Text
                  , ruleNArgs :: Int
                  }
        deriving (Generic, Serialise, Show)

