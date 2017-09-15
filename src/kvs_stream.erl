-module(kvs_stream).
-include("kvs.hrl").
-include("user.hrl").
-compile(export_all).
-export([ new/1, top/1, bot/1, take/2, load/1, save/1, seek/2, next/1, prev/1, add/3 ]).

% PUBLIC

new(T)                -> #cur{feed=kvs:next_id(cur,1),tab=T}.
top(#cur{top=[]}=C)   -> C#cur{val=[]};
top(#cur{top=T}=C)    -> seek(T,C).
bot(#cur{bot=[]}=C)   -> C#cur{val=[]};
bot(#cur{bot=B}=C)    -> seek(B,C).
take(N,#cur{dir=D}=C) -> take(D,N,C,[]).
save(C)               -> kvs:put(C), C.
load(#cur{feed=K})    -> kvs:get(cur,K).

seek(Id, #cur{tab=T}=C)    -> {ok,R}=kvs:get(T,Id),   C#cur{val=R}.
next(#cur{tab=T,val=[]}=C) -> {error,[]};
next(#cur{tab=T,val=B}=C)  -> lookup(kvs:get(T,en(B)),C).
prev(#cur{tab=T,val=[]}=C) -> {error,[]};
prev(#cur{tab=T,val=B}=C)  -> lookup(kvs:get(T,ep(B)),C).

add(top,M,#cur{top=T,val=[]}=C) -> Id=id(M), N=sp(sn(M,T),[]), kvs:put(N), C#cur{val=N,bot=Id,top=Id};
add(bot,M,#cur{bot=B,val=[]}=C) -> Id=id(M), N=sn(sp(M,B),[]), kvs:put(N), C#cur{val=N,bot=Id,top=Id};
add(top,M,#cur{top=T, val=V}=C) when element(2,V) /=T -> add(top, M, top(C));
add(bot,M,#cur{bot=B, val=V}=C) when element(2,V) /=B -> add(bot, M, bot(C));
add(top,M,#cur{top=T, val=V}=C) -> Id=id(M), N=sp(sn(M,T),[]), kvs:put([N,sp(V,Id)]), C#cur{val=N,top=Id};
add(bot,M,#cur{bot=B, val=V}=C) -> Id=id(M), N=sn(sp(M,B),[]), kvs:put([N,sn(V,Id)]), C#cur{val=N,bot=Id}.

remove(Id, #cur{tab=M}=C) ->
    {ok,R}=kvs:get(M,Id),
    join(M,Id,lists:map(fun(X)->fix(kvs:get(M,X))end,[ep(R),en(R)]),C).

join(T,I,[[],[]],C) ->                                          kvs:delete(T,I), C#cur{top=[],bot=[],val=[]};
join(T,I,[[], R],C) -> N=sp(R,[]),    kvs:put(N),               kvs:delete(T,I), C#cur{top=id(N),val=N};
join(T,I,[L, []],C) -> N=sn(L,[]),    kvs:put(N),               kvs:delete(T,I), C#cur{bot=id(N),val=N};
join(T,I,[L,  R],C) -> N=sp(R,id(L)), kvs:put([N,sn(L,id(R))]), kvs:delete(T,I), C#cur{val=N}.

sn(M,T)   -> setelement(#iterator.next, M, T).
sp(M,T)   -> setelement(#iterator.prev, M, T).
el(X,T)   -> element(X,T).
tab(T)    -> element(1,T).
id(T)     -> element(2,T).
en(T)     -> element(#iterator.next, T).
ep(T)     -> element(#iterator.prev, T).
dir(next) -> top;
dir(prev) -> bot.
down(C)   -> C#cur{dir=next}.
up(C)     -> C#cur{dir=prev}.

fix({ok,O})      -> O;
fix(_)           -> [].

lookup({ok,R},C) -> C#cur{id=el(2,R),val=R};
lookup(X,C)      -> X.

take(_,_,{error,_},R)     -> lists:flatten(R);
take(_,0,_,R)             -> lists:flatten(R);
take(A,N,#cur{val=B}=C,R) -> take(A,N-1,?MODULE:A(C),[B|R]).

check() -> test(), test2(), ok.

test2() ->
    #cur{feed = K} = Cur = new(user),
    Feed = lists:concat(["cur",K]),
    Ids = [A,B,C,D] = [ kvs:next_id(user,1) || _ <- lists:seq(1,4) ],
    R = save(add(top,#user{id=A},
             add(bot,#user{id=B},
             add(top,#user{id=C},
             add(bot,#user{id=D}, Cur ))))),
    X = remove(A,
        remove(B,
        remove(C,
        remove(D,R)))),
    [] = take(-1,down(top(X))).

test() ->
    #cur{feed = K} = Cur = new(user),
    take(-1,down(top(Cur))),
    Feed = lists:concat(["cur",K]),
    Ids = [A,B,C,D] = [ kvs:next_id(user,1) || _ <- lists:seq(1,4) ],
    R = save(add(top,#user{id=A},
             add(bot,#user{id=B},
             add(top,#user{id=C},
             add(bot,#user{id=D}, Cur ))))),
    X = take(-1,down(top(R))),
    Y = take(-1,up(bot(R))),
    X = lists:reverse(Y),
    L = length(X).