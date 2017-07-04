module Comms exposing (..)
import Json.Decode as Jd
import Json.Encode as Je
import Types exposing (..)
import Dict exposing (Dict)
import Debug
import Http



-- shorthand record describing the fundamental 
-- units of a server communication.
type alias Comm a msg =
  { send : Server
  , read : Jd.Decoder a
  , wrap : ( Result Http.Error a -> msg )
  }

-- generic function for pushing a value to a server.
push : Comm a msg -> Je.Value  -> Cmd msg
push comm value =
  let
    body = Http.jsonBody value
  in
    Http.post comm.send body comm.read
    |> Http.send comm.wrap


-- generic function for pulling some value from a server.
pull : Comm a msg -> Cmd msg
pull comm =
  Http.get comm.send comm.read
  |> Http.send comm.wrap


-- pull a survey spec from the server.
pull_survey : Config -> Cmd Msg
pull_survey config =
  let
    wrap = (\ rslt ->
        Recv ( Update rslt )
        )
  in
    pull
      { send = config.srvr
      , read = jd_survey
      , wrap = wrap
      }


-- push an archive to the server.
push_archive : Config -> Archive -> Cmd Msg
push_archive config arch =
  let
    data = je_archive arch
    comm =
      { send = config.srvr
      , read = Jd.succeed ()
      , wrap = (\ rslt ->
        Recv ( Upload rslt ) )
      }
  in
    push comm data


-- process a server response, possibly generating a `Pgrm`.
process_rsp : Maybe Pgrm -> Rsp -> Maybe Pgrm
process_rsp pgrm rsp = 
  case pgrm of
    -- if `pgrm` exists, `rsp`.
    Just pgrm ->
      case rsp of
        Update rsp ->
          Just ( apply_update pgrm rsp )
        
        Upload rsp ->
          Just ( assess_upload pgrm rsp )

    -- if no `pgrm` supplied, we are in `Init` case.
    Nothing ->
      case rsp of
        -- attempt to initialize the pgrm.
        Update rsp ->
          initialize_pgrm rsp
        -- anything other than an update is an error.
        _  ->
          let _ = Debug.log "unexpected comms" rsp
          in Nothing


-- attempt to generate a new pgrm instance from a server response.
initialize_pgrm : Result Http.Error Survey -> Maybe Pgrm
initialize_pgrm result =
  case result of
    Ok survey ->
      Just
        { spec = survey
        , sess = Dict.empty
        , arch = []
        }
    Err err ->
      let _ = Debug.log "http error" err
      in Nothing


-- apply the new survey spec to `pgrm` if possible.
apply_update : Pgrm -> Result Http.Error Survey -> Pgrm
apply_update pgrm result =
  case result of
    Ok(survey) ->
      { pgrm | spec = survey , sess = Dict.empty }

    Err(error) ->
      let _ = Debug.log "error: " error
      in pgrm

-- assess the result of an upload attempt, and dispose
-- of the corresponding archive if able.
assess_upload : Pgrm -> Result Http.Error () -> Pgrm
assess_upload pgrm result =
  case result of
    Ok (rsp) ->
      let _ = Debug.log "upload ok" rsp
      in { pgrm | arch = [] }

    Err (err) ->
      let _ = Debug.log "upload err" err
      in pgrm


-- encodes an archive list to a json value.
je_archive : Archive -> Je.Value
je_archive arch =
  let
    responses = List.map je_response arch
  in
    Je.list responses


-- encodes a response record to a json value.
je_response : Response -> Je.Value
je_response rsp =
  let
    time = Je.int rsp.time
    code = Je.int rsp.code
    sels = Je.list ( List.map je_selection rsp.sels )
  in
    Je.object
      [ ( "time" , time )
      , ( "code" , code )
      , ( "sels" , sels )
      ]


-- encodes a selection record to a json value.
je_selection : Selection -> Je.Value
je_selection sel =
  let
    itm = Je.int sel.itm
    opt = Je.int sel.opt
  in
    Je.object
      [ ( "itm" , itm )
      , ( "opt" , opt )
      ]


-- decodes a json string into a survey spec.
jd_survey : Jd.Decoder Survey
jd_survey =
  let
    text = Jd.field "text"   Jd.string
    code = Jd.field "code"   Jd.int
    itms = Jd.field "itms" ( Jd.list jd_question )
  in
    Jd.map3 Survey text code itms


-- decodes a json string into a question spec.
jd_question : Jd.Decoder Question
jd_question =
  let
    text = Jd.field "text" Jd.string
    code = Jd.field "code" Jd.int
    opts = Jd.field "opts" ( Jd.list jd_option )
  in
    Jd.map3 Question text code opts


-- decodes a json string into an option spec.
jd_option : Jd.Decoder Option
jd_option =
  let
    text = Jd.field "text" Jd.string
    code = Jd.field "code" Jd.int
  in
    Jd.map2 Option text code
