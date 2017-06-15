-module(permit_sup).
-behaviour(supervisor).

-export([
   start_link/0, init/1
]).

%%
-define(CHILD(Type, I),            {I,  {I, start_link,   []}, permanent, 5000, Type, dynamic}).
-define(CHILD(Type, I, Args),      {I,  {I, start_link, Args}, permanent, 5000, Type, dynamic}).
-define(CHILD(Type, ID, I, Args),  {ID, {I, start_link, Args}, permanent, 5000, Type, dynamic}).

%%-----------------------------------------------------------------------------
%%
%% supervisor
%%
%%-----------------------------------------------------------------------------

start_link() ->
   supervisor:start_link({local, ?MODULE}, ?MODULE, []).
   
init([]) ->   
   {ok,
      {
         {one_for_one, 4, 1800},
         [
            ?CHILD(worker, pts, spec())
         ]
      }
   }.


spec() ->
   Backend = opts:val(backend, permit_pubkey_io, permit),
   Storage = opts:val(storage, permit),
   [permit, 
      [
         'read-through',
         {factory, temporary},
         {entity,  {Backend, start_link, [Storage]}}
      ]
   ].   
