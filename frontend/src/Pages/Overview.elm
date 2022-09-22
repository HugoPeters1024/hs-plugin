module Pages.Overview exposing (view, init, update)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import HtmlHelpers exposing (..)
import Types exposing (..)
import ElmHelpers as EH

import UI.FileDropper as FileDropper

import Time
import Json.Decode

import Bootstrap.Table as Table
import Bootstrap.Button as Button
import Bootstrap.Alert as Alert
import File
import File.Select exposing (file)
import Task
import File
import Zip
import Zip.Entry 
import Dict
import Generated.Decoders

lift : OverviewMsg -> Msg
lift = Types.MsgOverViewTab

init : OverviewTab
init = { stagedProjects = []
       , problem = Nothing
       , captures = []
       , filedropper = FileDropper.init ["application/zip"]
       }

update : OverviewMsg -> OverviewTab -> (OverviewTab, Cmd Msg)
update msg tab = case msg of
    OverviewMsgStageCapture cv -> ({tab | stagedProjects = tab.stagedProjects ++ [cv]}, Cmd.none)
    OverviewMsgReadFile filename content -> case Zip.fromBytes content |> Maybe.map Zip.entries of
      Nothing -> (overviewSetProblem (filename ++ " is not a valid zip archive") tab, Cmd.none)
      Just entries -> 
        let dict = Dict.fromList (EH.annotate Zip.Entry.basename entries)
        in case Dict.get "capture.json" dict of
          Nothing -> (overviewSetProblem (filename ++  " does not contain a capture.json file") tab, Cmd.none)
          Just entry -> case Zip.Entry.toString entry of
            Err _ -> (overviewSetProblem ("there was a problem reading the content of capture.json in " ++ filename) tab, Cmd.none)
            Ok string_content -> case Json.Decode.decodeString Generated.Decoders.captureDecoder string_content of
              Err _ -> (overviewSetProblem ("there was a problem decoding the content of capture.json in " ++ filename) tab, Cmd.none)
              Ok capture -> 
                let capture_view = { capture = capture
                                   , files = dict
                                   , filename = filename
                                   }
                in ( {tab | captures = tab.captures ++ [capture_view]}
                     |> overviewRemoveProblem
                   , Cmd.none
                   )
    OverviewMsgDismissProblem _ -> ({tab | problem = Nothing}, Cmd.none)
    OverviewMsgFileDropper filemsg ->
      let (filedropper, cmd, files) = FileDropper.update filemsg tab.filedropper
          cmds = List.map (\file -> Task.perform (lift << OverviewMsgReadFile (File.name file)) (File.toBytes file)) files
      in ( { tab | filedropper = filedropper }
         , Cmd.batch ((Cmd.map (lift << OverviewMsgFileDropper) cmd) :: cmds)
         )



view : Model -> Html Msg
view m = 
    let
        mkRow cv = 
            Table.tr []
                [ Table.td [] 
                    [ Button.button 
                        [ Button.secondary
                        , Button.success
                        , Button.attrs [class "bi bi-arrow-bar-down", onClick (lift (OverviewMsgStageCapture cv))]
                        ] []
                    ]
                , Table.td [] [text cv.filename]
                , Table.td [] [text cv.capture.captureName]
                , Table.td [] [text cv.capture.captureGhcVersion]
                , Table.td [] [text (renderDateTime m.timezone (Time.millisToPosix cv.capture.captureDate))]
                ] 
    in div []
           [ h1 [] [text "Overview"]
           , hr [] []
           , EH.maybeHtml m.overviewTab.problem <| \problem -> 
                Alert.config
                |> Alert.danger
                |> Alert.dismissable (lift << OverviewMsgDismissProblem)
                |> Alert.children [text problem]
                |> Alert.view Alert.shown
           , FileDropper.viewConfig (lift << OverviewMsgFileDropper)
                |> FileDropper.view m.overviewTab.filedropper
           , span [] [h2 [] [text "Captures"]]
           , Table.table
               { options = [Table.striped, Table.hover]
               , thead = Table.simpleThead
                   [ Table.th [] [text "Actions"]
                   , Table.th [] [text "Capture Archive"]
                   , Table.th [] [text "Capture Slug"]
                   , Table.th [] [text "GHC Version"]
                   , Table.th [] [text "Captured at"]
                   ]
               , tbody = Table.tbody [] (List.map mkRow m.overviewTab.captures)
               }
           , hr [] []
           , h2 [] [text "Staged"]
           , HtmlHelpers.list (List.map (text << .captureName << .capture) m.overviewTab.stagedProjects)
           , hr [] []
           , Button.button 
               [ Button.primary
               , Button.disabled (List.isEmpty m.overviewTab.stagedProjects)
               , Button.attrs [onClick MsgOpenCodeTab]
               ] 
               [text "Open Tab"]
           ]



