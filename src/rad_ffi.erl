-module(rad_ffi).

-export([
    decode_object/1,
    encode_json/1,
    gleam_run/2,
    maybe_run/2,
    rename/2,
    toml_get/2,
    toml_new/0,
    toml_read_file/1,
    working_directory/0
]).

%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%%
%% Runtime Functions                      %%
%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%%

encode_json(Data) ->
    thoas:encode(Data).

gleam_run(Package, Module) ->
    [Main, Run] = atomize(Package, Module),
    apply(Main, run, [Run]).

maybe_run(Package, Module) ->
    [Run] = atomize(Module),
    ensure_loaded(Module, fun() ->
        case erlang:function_exported(Run, main, 0) of
            true ->
                gleam_run(Package, Module),
                {ok, <<"">>};
            false ->
                snag:error(<<"`", Module/binary, ".main` not found">>)
        end
    end).

ensure_loaded(Module, Callback) ->
    [X] = atomize(Module),
    code:purge(X),
    code:delete(X),
    case code:ensure_loaded(X) of
        {error, _any} ->
            snag:error(<<"failed to load module `", Module/binary, "`">>);
        _else ->
            Callback()
    end.

atomize(Package, Module) ->
    Main = binary_to_atom(<<Package/binary, "@@main">>),
    Run = atomize(Module),
    [Main | Run].

atomize(Module) ->
    X = binary:replace(Module, <<"/">>, <<"@">>, [global]),
    [binary_to_atom(X)].

%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%%
%% TOML Functions                         %%
%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%%

decode_object(Data) ->
    gleam_stdlib:decode_map(Data).

toml_get(Toml, KeyPath) ->
    gleam@result:nil_error(tomerl:get(Toml, KeyPath)).

toml_new() ->
    maps:new().

toml_read_file(Pathname) ->
    gleam@result:nil_error(tomerl:read_file(Pathname)).

%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%%
%% File System Functions                  %%
%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%%

rename(Source, Dest) ->
    case file:rename(Source, Dest) of
        ok ->
            {ok, nil};
        Error ->
            Error
    end.

working_directory() ->
    file:get_cwd().
