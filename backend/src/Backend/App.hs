{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Backend.App where

import Control.Exception.Safe (bracket)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (FromJSON, ToJSON, eitherDecode)
import qualified Data.ByteString.Lazy as B
import Data.Either (either)
import Data.Monoid ((<>))
import GHC.Generics (Generic)
import Katip (LogContexts, Severity (CriticalS, InfoS), Verbosity (V2), closeScribes, logTM, ls,
              runKatipContextT)
import Katip.Scribes.Handle (ioLogEnv)
import System.Directory
import System.Envy (DefConfig (defConfig), FromEnv, decodeEnv)
import System.Exit (die)

import Backend.Site (Site)
import Backend.Stack (Stack)

-- Application environment variables

data Env = Env
  { port :: Int -- "PORT"
  } deriving (Generic, Eq, Show)

instance DefConfig Env where
  defConfig = Env 3000

instance FromEnv Env

-- Application JSON configuration

data Config = Config
  { sites :: [Site]
  } deriving (Show, Eq, Generic)

instance FromJSON Config
instance ToJSON Config

loadConfig :: IO (Either String Config)
loadConfig = do
  userConfig <- getXdgDirectory XdgConfig "slownews.json"
  f <- doesPathExist userConfig >>= \case
    True -> pure userConfig
    False -> pure "config.json"
  content <- B.readFile f
  pure $ eitherDecode content

-- Application data structure

data App = App
  { env    :: Env
  , config :: Config
  } deriving (Show, Eq)

makeApp :: Stack App
makeApp = do
  appEnvE <- liftIO decodeEnv
  configE <- liftIO loadConfig
  either quitApp return $ App <$> appEnvE <*> configE

runApp :: Stack () -> IO ()
runApp f = do
  let mkLogEnv = ioLogEnv InfoS V2
  bracket mkLogEnv closeScribes $ \le ->
    runKatipContextT le (mempty :: LogContexts) mempty f

quitApp :: String -> Stack a
quitApp err = do
  $(logTM) CriticalS $ ls err'
  liftIO $ die err'
  where
    err' = "Application error: " <> err
