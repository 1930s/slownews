{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Frontend.App where

import Control.Monad (void)
import Data.Function (on)
import Data.List (sortBy)
import Data.Semigroup ((<>))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Data.Time.Format (defaultTimeLocale, formatTime)

import Reflex.Dom.Core hiding (Link)

import Common.Link (Link (..))
import Frontend.ReflexUtil (matchMaybe, matchEither, getAndDecodeWithError)

-- TODO: Rename Link type; conflicts with other modules.
type CurrentLinks = Maybe (Either String [Link])

app :: MonadWidget t m => m ()
app = divClass "ui container" $ do
  divClass "ui segment" $ do
    elClass "h1" "header" $ text "SlowNews"
    divClass "content" $ do
      viewLinks =<< getLinks
  divClass "footer" $ do
    elAttr "a" ("href" =: "https://github.com/srid/slownews") $ do
      text "SlowNews on GitHub (powered by Haskell and Reflex)"

viewLinks :: MonadWidget t m => Dynamic t CurrentLinks -> m ()
viewLinks links'' = divClass "ui very basic table" $ matchMaybe links'' $ \case
  Nothing -> divClass "ui text loader" $ text "Loading..."
  Just links' -> matchEither links' $ \case
    Left err -> dynText $ T.pack <$> err
    Right links -> void $ simpleList (sortLinks <$> links) viewLink
  where
    sortLinks = sortBy (flip compare `on` linkCreated)

viewLink :: MonadWidget t m => Dynamic t Link -> m ()
viewLink dLink = el "tr" $ do
  el "td" $ do
    dynText $ dayOfWeek . linkCreated <$> dLink
  elClass "td" "meta" $ do
    dynA (linkMetaUrl <$> dLink) (linkSite <$> dLink)
  el "td" $ do
    dynA (linkUrl <$> dLink) (linkTitle <$> dLink)
  where
    dayOfWeek = T.pack . formatTime defaultTimeLocale "%a" . posixSecondsToUTCTime . fromIntegral

-- | Like dynText but for <a href...
dynA :: MonadWidget t m => Dynamic t T.Text -> Dynamic t T.Text -> m ()
dynA url title = elDynAttr "a" dAttr $ dynText title
  where dAttr = ffor url $ \u -> "href" =: u

getBaseUrl :: Monad m => m Text
getBaseUrl = do
  -- FIXME: change this after fixing the backend
  -- We need to inject from Obelisk.
  -- cf. https://github.com/obsidiansystems/obelisk/pull/91
  -- pure "https://slownews.srid.ca"
  pure ""

-- | Fetch links from the server
getLinks :: MonadWidget t m => m (Dynamic t CurrentLinks)
getLinks = do
  baseUrl <- getBaseUrl
  pb <- getPostBuild
  let urlEvent = baseUrl <> "/data" <$ pb
  resp <- getAndDecodeWithError urlEvent
  holdDyn Nothing $ Just <$> resp
