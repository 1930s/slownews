import Http
import Html.Attributes exposing (..)
import Signal
import String
import Result
import Date
import Set
import Task exposing (..)
import Html as H
import Html exposing (Html)
import Json.Decode  as J
import Json.Decode exposing ((:=))
import Json.Encode as JE

-- Model

type alias Link =
  { title     : String
  , url       : String
  , metaUrl   : String
  , created   : Date.Date
  , site      : String
  }

type alias Model =
  List Link

dateToString : Date.Date -> String
dateToString date =
  String.join ""
          [ Date.dayOfWeek date |> toString
          , ", "
          , Date.month date |> toString
          , " "
          , Date.day date |> toString
          , " " ]


summarizeLinks : List Link -> String
summarizeLinks =
  (List.map .site) >> Set.fromList >> Set.toList >> String.join ":"

-- JSON decoders

andMap : J.Decoder (a -> b) -> J.Decoder a -> J.Decoder b
andMap = J.object2 (<|)

dateFromUnix unixtime =
  unixtime * 1000 |> toFloat |> Date.fromTime |> Result.Ok

decodeDate : J.Decoder (Date.Date)
decodeDate = J.customDecoder J.int dateFromUnix 

decodeLink : J.Decoder Link
decodeLink = Link
  `J.map`   ("title"     := J.string)
  `andMap`  ("url"       := J.string)
  `andMap`  ("meta_url"  := J.string)
  `andMap`  ("created"   := decodeDate)
  `andMap`  ("site"      := J.string)

decodeModel : J.Decoder Model
decodeModel = J.list decodeLink


-- Main routines

getData : Task Http.Error Model
getData =
  Http.get decodeModel "/data"

dataMailbox : Signal.Mailbox Model
dataMailbox =
  Signal.mailbox []

port runner : Task Http.Error ()
port runner =
  getData `andThen` (Signal.send dataMailbox.address)

main : Signal Html
main =
  Signal.map view dataMailbox.signal


-- View

view : Model -> Html
view links =
  let
    mainView = viewLinks links
    allViews  = [mainView, viewFooter]
  in
    H.div [] allViews

viewLinks : List Link -> Html
viewLinks links =
  let
    orderedLinks  = links |> List.sortBy (.created >> Date.toTime) |> List.reverse
    siteTitle     = "Current week for - " ++ (summarizeLinks links)
  in
    H.div [class "site"]
       [ H.h2 [] [H.text siteTitle]
       , H.ul [] <| List.map viewLink orderedLinks ]

viewLink : Link -> Html
viewLink link =
  H.li []
     [ H.text <| "[" ++ (link.created |> Date.dayOfWeek |> toString) ++ "] "
     , H.a [href link.url] [H.text link.title]
     , H.text " "
     , H.a [class "meta", href link.metaUrl, title (link.created |> dateToString)] [H.text link.site] ]

viewFooter : Html
viewFooter =
  H.div [id "footer"]
   [ H.a [href "https://github.com/srid/slownews"] [H.text "Fork SlowNews on GitHub"]]
