%%%-------------------------------------------------------------------
%%% @author V. Glenn Tarcea <glenn.tarcea@gmail.com>
%%% @copyright (C) 2012, V. Glenn Tarcea
%%% @doc
%%%
%%% @end
%%% Created : 12 Nov 2012 by V. Glenn Tarcea <glenn.tarcea@gmail.com>
%%%-------------------------------------------------------------------
-module(send_file).

-include_lib("kernel/include/file.hrl").

%% API
-export([send_file/2]).

%% Macros
-define(DEFAULT_PORT, 1055).


%%%===================================================================
%%% API
%%%===================================================================

send_file(Filepath, Uuid) ->
    {ok, #file_info{size = FileSize}} = file:read_file_info(Filepath),
    {ok, Checksum} = checksum(Filepath),
    {ok, Socket} = gen_tcp:connect("127.0.0.1", ?DEFAULT_PORT,
                        [binary, {packet, raw}, {active, false}]),
    Basename = filename:basename(Filepath),
    BinTerm = term_to_binary([{filename, Basename}, {uuid, Uuid},
                    {size, FileSize}, {checksum, Checksum}]),
    %gen_tcp:send(Socket, Basename),
    gen_tcp:send(Socket, BinTerm),
    {ok, Packet} = gen_tcp:recv(Socket, 0),
    case binary_to_term(Packet) of
        already_downloaded -> RV = {ok, 0, FileSize};
        {ok, ExistingSize} ->
    %{ok, ExistingSize} = binary_to_term(Packet),
            io:format("ExistingSize = ~p~n", [ExistingSize]),
            {ok, Fd} = file:open(Filepath, [raw, binary, read]),
            {ok, BytesSent} = file:sendfile(Fd, Socket, ExistingSize, 0, []),
            file:close(Fd),
            RV = {ok, BytesSent, FileSize}
    end,
    gen_tcp:close(Socket),
    RV.

checksum(Filepath) ->
    checksum_rv(checksums:md5sum(Filepath)).

checksum_rv({error, _Reason}) -> error;
checksum_rv(Checksum) -> {ok, Checksum}.
