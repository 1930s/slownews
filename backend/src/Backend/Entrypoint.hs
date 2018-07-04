{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Backend.Entrypoint where
import Control.Concurrent.Async.Lifted (mapConcurrently)
import Control.Concurrent.Lifted (fork, threadDelay)
import Control.Concurrent.STM (TVar, atomically, newTVar, readTVar, writeTVar)
import Control.Exception.Safe (handle)
import Control.Monad (forever, join)
import Control.Monad.IO.Class (liftIO)
import Data.Monoid ((<>))
import Katip (Severity (ErrorS, InfoS), logTM, showLS)
import Network.HTTP.Client (HttpException)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Network.Wai.Middleware.Static (addBase, noDots, staticPolicy, (>->))
import System.Directory (doesFileExist, getCurrentDirectory)
import System.FilePath (FilePath, joinPath)
import Web.Scotty (get, json, middleware, redirect, scotty, setHeader)

import qualified Backend.App as App
import qualified Backend.Site as Site
import Backend.Stack (Stack)
import Common.Link (Link)

type Links = TVar [Link]

fetchAll :: App.App -> Links -> Stack ()
fetchAll app links = do
  results <- fetchSites sites
  liftIO $ storeTVar links results
  $(logTM) InfoS "Finished"
  where
    sites = App.sites $ App.config app
    fetchSites = fmap join . mapConcurrently Site.fetchSite
    storeTVar tvar = atomically . writeTVar tvar

handleHttpException :: HttpException -> Stack ()
handleHttpException e = do
  $(logTM) ErrorS $ "Http exception:" <> showLS e
  return ()

fetchAll' :: App.App -> Links -> Stack ()
fetchAll' app links = handle handleHttpException (fetchAll app links)

getStaticDir :: Stack FilePath
getStaticDir = do
  -- ./static has static files, from frontend
  cwd <- liftIO $ getCurrentDirectory
  let staticDir = joinPath [cwd, "static"]
  -- index.html and friends must have been generated from frontend
  hasIndex <- liftIO $ doesFileExist (joinPath [staticDir, "index.html"])
  case hasIndex of
    True  -> liftIO $ return staticDir
    False -> App.quitApp $ staticDir <> " is not a valid static directory"

start :: IO ()
start = App.runApp $ do
  app <- App.makeApp
  $(logTM) InfoS $ showLS app
  links <- liftIO $ atomically $ newTVar mempty
  _ <- fork $ forever (fetchAll' app links >> sleepM 30)
  webroot <- getStaticDir
  $(logTM) InfoS $ "Static directory: " <> showLS webroot
  liftIO $ scotty (port app) $ do
    middleware $ logStdoutDev
    middleware $ staticPolicy (noDots >-> addBase webroot)
    get "/" $ redirect "/index.html"
    get "/data" $ do
      d <- liftTVar links
      setHeader "Access-Control-Allow-Origin" "*"
      json d
  where
    port = App.port . App.env
    liftTVar = liftIO . atomically . readTVar
    sleepM n = threadDelay (n * 60 * 1000 * 1000) -- sleep in minutes

main :: IO ()
main = App.runApp $ do
  app <- App.makeApp
  $(logTM) InfoS $ showLS app
  links <- liftIO $ atomically $ newTVar mempty
  _ <- fork $ forever (fetchAll' app links >> sleepM 30)
  webroot <- getStaticDir
  $(logTM) InfoS $ "Static directory: " <> showLS webroot
  liftIO $ scotty (port app) $ do
    middleware $ logStdoutDev
    middleware $ staticPolicy (noDots >-> addBase webroot)
    get "/" $ redirect "/index.html"
    get "/data" $ do
      d <- liftTVar links
      setHeader "Access-Control-Allow-Origin" "*"
      json d
  where
    port = App.port . App.env
    liftTVar = liftIO . atomically . readTVar
    sleepM n = threadDelay (n * 60 * 1000 * 1000) -- sleep in minutes
