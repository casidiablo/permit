%% @doc 
%%   https://crackstation.net/hashing-security.htm
%%   1. hash and salt password using sha256 and 256-bit salt
%%   2. use PBKDF2 to stretch key
%%   3. encrypt hash using AES
%%
%% @todo
%%   * token scope 
-module(permit).
-include("permit.hrl").

-export([start/0]).
-export([
   signup/2,
   signin/2,
   pubkey/1,

   auth/2,
   check/1
]).

%%
%% data types
-type(user()   :: binary()).
-type(pass()   :: binary()).
-type(access() :: binary()).
-type(secret() :: binary()).
-type(token()  :: binary()).


%%
%%
start() ->
   applib:boot(?MODULE, code:where_is_file("app.config")).

%%
%% sing-up to service, creates root account, returns access token
%% (note: tx id is used as collision conflict resolution)
-spec(signup/2 :: (user(), pass()) -> {ok, token()} | {error, any()}).

signup(User, Pass) ->
   case 
      permit_pubkey:create(?CONFIG_SYS, 
         permit_pubkey:new(root, User, Pass)
      ) 
   of
      {ok, Entity} ->
         permit_pubkey:auth(?CONFIG_CACHE, Entity);
      {error,   _} = Error ->
         Error
   end.

%%
%% validate root account credentials, return access token
-spec(signin/2 :: (user(), pass()) -> {ok, token()} | {error, any()}).

signin(User, Pass) ->
   case 
      permit_pubkey:lookup(?CONFIG_SYS, 
         permit_pubkey:new(root, User, Pass)
      ) 
   of
      {ok, Entity} ->
         permit_pubkey:auth(?CONFIG_CACHE, Entity);
      {error,   _} = Error ->
         Error
   end.
      
%%
%% generate access/secret keys, associate them with root account
-spec(pubkey/1 :: (token()) -> {ok, {access(), secret()}} | {error, any()}).

pubkey(Token) ->
   case memcache:get(?CONFIG_CACHE, Token) of
      {ok, Urn} ->
         key_pair(Urn);
      Error   ->
         Error
   end.   

key_pair(<<"urn:root", _/binary>> = Urn) ->
   Access = permit_hash:key(?CONFIG_ACCESS),
   Secret = permit_hash:key(?CONFIG_SECRET),
   case 
      permit_pubkey:create(?CONFIG_SYS, 
         permit_pubkey:new(pubkey, Access, Secret) ++ [{<<"link">>, Urn}]
      ) 
   of
      {ok, _Entity} ->
         {ok, {Access, Secret}};

      {error,   _} = Error ->
         Error
   end;
   
key_pair(_) ->
   {error, unauthorized}.

%%
%% authorize keys, return token
-spec(auth/2 :: (access(), secret()) -> {ok, token()}). 

auth(Access, Secret) ->
   case 
      permit_pubkey:lookup(?CONFIG_SYS, 
         permit_pubkey:new(pubkey, Access, Secret)
      )
   of
      {ok, Entity} ->
         permit_pubkey:auth(?CONFIG_CACHE, Entity);
      {error,   _} = Error ->
         Error
   end.

%%
%% validate access token
-spec(check/1 :: (token()) -> {ok, atom()} | {error, any()}).

check(Token) ->
   case memcache:get(?CONFIG_CACHE, Token) of
      {ok, <<"urn:root:", _/binary>>} ->
         {ok, root};
      {ok, <<"urn:pubkey:", _/binary>>} ->
         {ok, pubkey};
      {ok, _} ->
         {error, unauthorized};
      Error   ->
         Error
   end.   

%%-----------------------------------------------------------------------------
%%
%% private
%%
%%-----------------------------------------------------------------------------




