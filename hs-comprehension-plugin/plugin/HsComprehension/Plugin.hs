{-# LANGUAGE CPP #-}
{-# LANGUAGE ScopedTypeVariables #-}
module HsComprehension.Plugin where

import Prelude as P
import Data.Maybe


# if MIN_VERSION_ghc(9,0,0)
import GHC.Plugins
# else
import GhcPlugins
# endif


import HsComprehension.Uniqify as Uniqify
import HsComprehension.Ast as Ast
import qualified HsComprehension.Cvt as Cvt
import HsComprehension.DefAnalysis

import Control.Monad.IO.Class
import Control.Monad
import qualified Data.ByteString.Lazy as BSL
import Codec.Serialise (Serialise)

import qualified Codec.Serialise as Ser
import qualified Codec.Compression.Zstd.Lazy as Zstd

import System.FilePath.Posix as FP
import System.Directory as FP
import System.IO (openFile, openTempFile, IOMode(..), stdout)
import System.IO.Unsafe (unsafePerformIO)
import GHC.IO.Handle
import Data.IORef

import Data.Text (Text)
import qualified Data.Text as T
import Data.Map (Map)
import qualified Data.Map as M
import Data.Set (Set)
import qualified Data.Set as S
import Data.List (isPrefixOf, splitAt)
import Data.Traversable (for)

import Text.Parsec as Parsec
import Text.Parsec.Number as Parsec

import Data.ByteString.Lazy (hPutStr)
import qualified GhcDump.Convert

import Data.Time
import Data.Time.Clock
import Data.Time.Clock.POSIX





type StdThief = (FilePath, Handle)

setupStdoutThief :: IO StdThief
setupStdoutThief = do
  tmpd <- getTemporaryDirectory
  (tmpf, tmph) <- openTempFile tmpd "haskell_stdout"
  stdout_dup <- hDuplicate stdout
  hDuplicateTo tmph stdout
  hClose tmph
  pure (tmpf, stdout_dup)

readStdoutThief :: StdThief -> IO String
readStdoutThief (tmpf, stdout_dup) = do
  hDuplicateTo stdout_dup stdout
  str <- readFile tmpf
  removeFile tmpf
  return str

eitherToMaybe :: Either a b -> Maybe b
eitherToMaybe (Left _) = Nothing
eitherToMaybe (Right x) = Just x

phaseMarkerParser :: Parsec.Parsec String () Int
phaseMarkerParser = id <$ Parsec.string "__PHASE_MARKER " <*> Parsec.int

ruleParser :: Int -> Parsec.Parsec String () Ast.FiredRule
ruleParser p = Ast.FiredRule
                 <$ Parsec.string "Rule fired: "
                 <*> (T.pack <$> Parsec.manyTill Parsec.anyChar (Parsec.try (Parsec.string " (")))
                 <*> (T.pack <$> Parsec.manyTill Parsec.anyChar (Parsec.try (Parsec.char ')')))
                 <*> pure (p+1)

parseStdout :: String -> [Ast.FiredRule]
parseStdout inp = reverse $ fst $ P.foldl go ([], 0) (lines inp)
    where go :: ([Ast.FiredRule], Int) -> String -> ([Ast.FiredRule], Int)
          go (acc, p) s =
              case eitherToMaybe (Parsec.runParser phaseMarkerParser () "stdout" s) of
                Just np -> (acc, np)
                Nothing -> case eitherToMaybe (Parsec.runParser (ruleParser p) () "stdout" s) of
                    Just x -> (x:acc, p)
                    Nothing -> (acc, p)


data CaptureView = CaptureView
  { cv_project_root :: FilePath
  }

defaultCaptureView :: CaptureView
defaultCaptureView = CaptureView
  { cv_project_root = "./"
  }


currentPosixMillis :: IO Int
currentPosixMillis =
  let posix_time =



        utcTimeToPOSIXSeconds <$> getCurrentTime

  in floor . (1e3 *) . toRational <$> posix_time

cvtGhcPhase :: DynFlags -> Int -> String -> ModGuts -> Ast.Phase
cvtGhcPhase dflags phaseId phase =
    let cvtEnv = Cvt.CvtEnv { Cvt.cvtEnvPhaseId = phaseId
                            , Cvt.cvtEnvBinders = []
                            }
    in Cvt.cvtPhase cvtEnv . GhcDump.Convert.cvtModule dflags phaseId phase

projectState :: IORef (Bool, StdThief, Capture)
projectState =  do
    let capture =
            Capture { captureName = T.empty
                    , captureDate = 0
                    , captureGhcVersion = T.pack "GHC version unknown"
                    , captureModules = []
                    }
    unsafePerformIO $ do
        time <- currentPosixMillis
        newIORef (False, undefined, capture { captureDate = time })

setupProjectStdoutThief :: IO ()
setupProjectStdoutThief = do
    thief <- setupStdoutThief
    modifyIORef projectState $ \(reset, _, capture) -> (reset, thief, capture)

plugin :: Plugin
plugin = defaultPlugin
  { installCoreToDos = install





  }













ensureOldDeleted :: String -> IO ()
ensureOldDeleted slug = do
  (isReset,_,_) <- readIORef projectState
  unless isReset $ do
    putStrLn "HsComprehension: Removing the old capture if it exists"
    exists <- FP.doesDirectoryExist (coreDumpDir defaultCaptureView slug)
    when exists $ do
      FP.removeDirectoryRecursive (coreDumpDir defaultCaptureView slug)
    modifyIORef projectState $ \(_,thief,capture) -> (True,thief,capture)

getGhcVersionString :: CoreM String
getGhcVersionString = do
  ghc_v <- ghcNameVersion <$> getDynFlags
  pure $ ghcNameVersion_programName ghc_v ++ " " ++ ghcNameVersion_projectVersion ghc_v

install :: [CommandLineOption] -> [CoreToDo] -> CoreM [CoreToDo]
install options todo = do


    liftIO $ putStrLn "HsComprehension: GHC < 9.0.0 requires manual enabling of -ddump-rule-firings to get complete telemetry"

    liftIO setupProjectStdoutThief
    let slug = case options of
                    [slug] -> slug
                    _      -> error "provide a slug for the dump as exactly 1 argument"
    liftIO $ print options
    liftIO $ ensureOldDeleted slug
    liftIO $ FP.createDirectoryIfMissing True (coreDumpDir defaultCaptureView slug)
    dflags <- getDynFlags
    modName <- showSDoc dflags . ppr <$> getModule
    ghcVersion <- T.pack <$> getGhcVersionString
    liftIO $ modifyIORef projectState $ \(setup, thief, capture) ->
        ( setup
        , thief
        , capture
            { captureModules = (T.pack modName, length todo) : captureModules capture
            , captureGhcVersion = ghcVersion
            , captureName = T.pack slug
            }
        )

    ms_ref <- liftIO $ newIORef []
    let dumpPasses = zipWith (dumpPass ms_ref) [1..] (map getPhase todo)
    let firstPass = dumpPass ms_ref 0 "Desugared"
    pure $ firstPass : (P.concat $ zipWith (\x y -> [x,y]) todo dumpPasses) ++ [finalPass ms_ref (slug, modName)]

getPhase :: CoreToDo -> String
getPhase todo = showSDocUnsafe (ppr todo) ++ " " ++ showSDocUnsafe (pprPassDetails todo)

printPpr :: (Outputable a, MonadIO m) => a -> m ()
printPpr a = liftIO $ putStrLn $ showSDocUnsafe (ppr a)

coreDumpBaseDir :: CaptureView -> String
coreDumpBaseDir view = cv_project_root view `FP.combine` "dist-newstyle"

coreDumpDir :: CaptureView -> String -> FilePath
coreDumpDir view pid = coreDumpBaseDir view `FP.combine` "coredump-" ++ pid

coreDumpFile :: CaptureView -> String -> String -> FilePath
coreDumpFile view pid mod = coreDumpDir view pid `FP.combine` mod ++ ".zstd"

captureFile :: CaptureView -> String -> FilePath
captureFile view pid = coreDumpDir view pid `FP.combine` "capture.zstd"

writeToFile :: (Serialise a) => FilePath -> a -> IO ()
writeToFile fname = do
    BSL.writeFile fname . Zstd.compress 7 . Ser.serialise

readFromFile :: Serialise a => FilePath -> IO a
readFromFile fname = do
    Ser.deserialise . Zstd.decompress <$> BSL.readFile fname

dumpPass :: IORef [Ast.Phase] -> Int -> String -> CoreToDo
dumpPass ms_ref n phase = CoreDoPluginPass "Core Snapshot" $ \in_guts -> do
    let guts = in_guts { mg_binds = Uniqify.freshenUniques (mg_binds in_guts) }
--    guts <- liftIO $ pure in_guts

    dflags <- getDynFlags
    let prefix :: String = showSDocUnsafe (ppr (mg_module guts))
    liftIO $ do
        putStrLn $ "__PHASE_MARKER " ++ show n
        let mod = cvtGhcPhase dflags n phase guts
        modifyIORef ms_ref (mod:)
    pure guts

finalPass :: IORef [Ast.Phase] -> (String, String) -> CoreToDo
finalPass ms_ref (slug, modName) = CoreDoPluginPass "Finalize Snapshots" $ \guts -> do
    liftIO $ do
        (_, thief, capture) <- readIORef projectState
        in_phases <- readIORef ms_ref
        r <- readStdoutThief thief
        let ruleFirings = parseStdout r
        putStrLn r

        let phases = defAnalysis $ zipWith (\ n p
              -> p {phaseFiredRules = filter
                                        ((== n) . firedRulePhase) ruleFirings}) [0..] (reverse in_phases)

        let mod = Ast.Module {
              Ast.moduleName = T.pack modName
            , Ast.modulePhases = phases
            }

        let fname = coreDumpFile defaultCaptureView slug modName
        writeToFile fname mod

        writeToFile (captureFile defaultCaptureView (T.unpack (captureName capture))) capture
    pure guts
