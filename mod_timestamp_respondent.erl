-module(mod_timestamp_respondent).

-behaviour(gen_mod).

-include("logger.hrl").
-include("translate.hrl").
-include_lib("xmpp/include/xmpp.hrl").

-export([start/2, stop/1, depends/2, mod_options/1, mod_doc/0]).
-export([user_send_packet/1,user_receive_packet/1]).

%%====================================================================
%% gen_mod callbacks
%%====================================================================

start(Host, _Opts) ->
  ?INFO_MSG("HELLO THERE", []),
  ejabberd_hooks:add(user_send_packet, Host, ?MODULE, user_send_packet, 0),
  ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, user_receive_packet, 0).

stop(Host) ->
  ?INFO_MSG("SEE YOU LATER", []),
  ejabberd_hooks:delete(user_send_packet, Host, ?MODULE, user_send_packet, 0),
  ejabberd_hooks:delete(user_receive_packet, Host, ?MODULE, user_receive_packet, 0).

depends(_Host, _Opts) ->
  [].

mod_options(_Host) ->
  [].

mod_doc() ->
  #{desc => ?T("Module replies with a current unix time to a sender")}.

%%====================================================================
%% Hook callbacks
%%====================================================================

% Lets react for only packets with message body
% (there are 3 separate packets with type = chat for 1 sended message).
% In this case it's not necessary to store IDs of messages
% (in gen_server for example) to avoid endless message exchange.
%
% Also I see the difference between message formats
% (because of different versions of ejabberd I suppose).
% So the decision to place Timestamp into metadata was accepted.
user_send_packet({#message{type = chat, from = From, body = Body, meta = Meta} = Msg,
                  C2SState}) when Body =/= [] ->
  Timestamp = os:system_time(second),
  Response = Msg#message{to = From, from = undefined, body = [],
                         meta = maps:put(timestamp, Timestamp, Meta)},
  ejabberd_router:route(Response),

  NewMsg = Msg#message{meta = maps:put(timestamp, Timestamp, Meta)},
  {NewMsg, C2SState};
user_send_packet(Pkt) ->
  Pkt.

% As a result we have next:
%  -reply:
% {received_msg,{message,<<"purple92cd8f00">>,chat,<<"en">>,undefined,
%                        {jid,<<"user2">>,<<"ruslan.muminov1.fvds.ru">>,
%                             <<"muckl">>,<<"user2">>,
%                             <<"ruslan.muminov1.fvds.ru">>,<<"muckl">>},
%                        [],[],undefined,
%                        [{xmlel,<<"active">>,
%                                [{<<"xmlns">>,
%                                  <<"http://jabber.org/protocol/chatstates">>}],
%                                []}],
%                        #{ip => {0,0,0,0,0,65535,28156,6709},
%                          stanza_id => 1624483881474484,
%                          timestamp => 1624483881}}}
%  -updated_message:
% {received_msg,{message,<<"purple92cd8f00">>,chat,<<"en">>,
%                        {jid,<<"user2">>,<<"ruslan.muminov1.fvds.ru">>,
%                             <<"muckl">>,<<"user2">>,
%                             <<"ruslan.muminov1.fvds.ru">>,<<"muckl">>},
%                        {jid,<<"user1">>,<<"ruslan.muminov1.fvds.ru">>,<<>>,
%                             <<"user1">>,<<"ruslan.muminov1.fvds.ru">>,<<>>},
%                        [],
%                        [{text,<<>>,<<"kkkkkkkk">>}],
%                        undefined,
%                        [{xmlel,<<"active">>,
%                                [{<<"xmlns">>,
%                                  <<"http://jabber.org/protocol/chatstates">>}],
%                                []}],
%                        #{ip => {0,0,0,0,0,65535,28156,6709},
%                          mam_archived => true,stanza_id => 1624483881489660,
%                          timestamp => 1624483881}}}
user_receive_packet({#message{type = chat} = Msg, _C2SState} = Pkt) ->
  ?INFO_MSG(term_to_string({received_msg, Msg}), []),
  Pkt;
user_receive_packet(Pkt) ->
  Pkt.

%%====================================================================
%% Internal functions
%%====================================================================

term_to_string(Term) ->
  R = io_lib:format("~p",[Term]),
  lists:flatten(R).
