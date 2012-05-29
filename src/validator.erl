-module(validator).

-export([behaviour_info/1]).

-export([
		validate/2,
		validate/3,
		assert_false/1,
		assert_true/1,
		email/1,
		future/1,
		past/1,
		size/5,
		size/2,
		not_blank/1,
		null/1,
		pattern/2,
		range/5,
		max/2,
		min/2,
		not_null/1
	]).

-define(EMAIL_REGEX, <<"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,4}$">>).

behaviour_info(callbacks) ->  [      
        {validations, 0}
    ];
behaviour_info(_) ->
    undefined.

validate(Obj, Validator) ->
	Results = lists:flatten([validate_field(Field, Validator:'#get-'(Field, Obj), Validations) || {Field, Validations} <- Validator:validations()]),
	case Results of
		[] -> ok;
		_ -> {validation_error, Results}
	end.

validate(Field, Obj, Validator) ->
	{_, Validations} = lists:keyfind(Field, 1, Validator:validations()),
	Result = validate_field(Field, Validator:'#get-'(Field, Obj), Validations),
	case Result of
		[] -> ok;
		_ -> {validation_error, Result}
	end.
	
validate_field(Field, Value, Validations) when is_list(Validations) ->
	lists:foldl(
		fun(Validation, Acc) ->
			try
				if
					is_atom(Validation) -> 
					                       	?MODULE:Validation(Value);
					is_tuple(Validation) ->	
					                       	ValidationList = tuple_to_list(Validation),
					                       	[Func] = lists:nth(1, ValidationList),
					                       	erlang:apply(?MODULE, Func, lists:nthtail(1, ValidationList))
				end,
				Acc
			catch 
				throw:validation_error -> [{Field, Value, Validation}] ++ Acc
			end
		end,
	[], Validations).

assert_false(Value) when is_boolean(Value) ->
	Value =:= false orelse throw(validation_validation_error).

assert_true(Value) when is_boolean(Value) ->
	Value =:= true orelse throw(validation_validation_error).

email(undefined) ->
	throw(validation_error);
email(Email) when is_binary(Email) ->
	email(binary_to_list(Email));
email(Email) when is_list(Email) ->
	case is_blank(Email) of
		true -> throw(validation_error);
		false ->
			{ok, RE} = re:compile(?EMAIL_REGEX, [caseless]),
			re:run(string:strip(Email), RE) =/= nomatch orelse throw(validation_error)
	end.

future(Value) when is_number(Value) ->
	Now = time_to_millis(now()),
	Value > Now orelse throw(validation_error);
future({Mega, Sec, Micro} = Value) when is_integer(Mega) andalso is_integer(Sec) andalso is_integer(Micro) ->
	Micros = time_to_micros(Value),
	Now = time_to_micros(now()),
	Micros > Now orelse throw(validation_error).

past(Value) when is_number(Value) ->
	Now = time_to_millis(now()),
	Value < Now orelse throw(validation_error);
past({Mega, Sec, Micro} = Value) when is_integer(Mega) andalso is_integer(Sec) andalso is_integer(Micro) ->
	Micros = time_to_micros(Value),
	Now = time_to_micros(now()),
	Micros < Now orelse throw(validation_error).

size(MinMax, Value) when is_list(Value) ->
	size(MinMax, true, MinMax, true).

size(Min, true, Max, true, Value) when is_list(Value) ->
	Length = length(Value),
	(Length >= Min andalso Length =<  Max) orelse throw(validation_error);
size(Min, true, Max, false, Value) when is_list(Value) ->
	Length = length(Value),
	(Length >= Min andalso Length <  Max) orelse throw(validation_error);
size(Min, false, Max, true, Value) when is_list(Value) ->
	Length = length(Value),
	(Length > Min andalso Length =<  Max) orelse throw(validation_error);
size(Min, false, Max, false, Value) when is_list(Value) ->
	Length = length(Value),
	(Length > Min andalso Length <  Max) orelse throw(validation_error).

max(Max, Value) ->
	Value =< Max orelse throw(validation_error).

min(Min, Value) ->
	Value >= Min orelse throw(validation_error).

not_blank(Value) when is_binary(Value) ->
	not_blank(binary_to_list(Value));  
not_blank(Value) when is_list(Value) ->
	not is_blank(Value) orelse throw(validation_error).

not_null(Value) when is_atom(Value) ->
	not is_null(Value) orelse throw(validation_error).

null(Value) ->
	is_null(Value) orelse throw(validation_error).

pattern(Pattern, Value) when is_binary(Pattern) andalso is_binary(Value) ->
	pattern(Pattern, binary_to_list(Value));
pattern(Pattern, Value) when is_binary(Pattern) andalso is_list(Value) ->
	{ok, RE} = re:compile(Pattern, []),
	re:run(string:strip(Value), RE) =/= nomatch orelse throw(validation_error).

range(Start, true, Stop, true, Value) when is_integer(Start) andalso is_integer(Stop) andalso is_number(Value) ->
	(Value >= Start andalso Value =< Stop) orelse throw(validation_error);
range(Start, true, Stop, false, Value) when is_integer(Start) andalso is_integer(Stop) andalso is_number(Value) ->
	(Value >= Start andalso Value < Stop) orelse throw(validation_error);
range(Start, false, Stop, true, Value) when is_integer(Start) andalso is_integer(Stop) andalso is_number(Value) ->
	(Value > Start andalso Value =< Stop) orelse throw(validation_error);
range(Start, false, Stop, false, Value) when is_integer(Start) andalso is_integer(Stop) andalso is_number(Value) ->
	(Value > Start andalso Value < Stop) orelse throw(validation_error).

%% Internal functions
time_to_millis({Mega, S, Micro}) ->
	(Mega * 1000000000) + (S * 1000) + (Micro div 1000).

time_to_micros({Mega, S, Micro}) ->
	(Mega * 1000000000000) + (S * 1000000) + Micro.

is_blank([]) ->
	true;
is_blank(<<"">>) ->
	true;
is_blank(Val) when is_atom(Val) andalso (Val =:= undefined orelse Val =:= null) ->
	true;
is_blank(Val) when is_list(Val) ->
	string:strip(Val) =:= [];
is_blank(Val) when is_binary(Val) ->
	is_blank(binary_to_list(Val)).

is_null(Val) when is_atom(Val) andalso (Val =:= undefined orelse Val =:= null) ->
	true;
is_null(_) ->
	false.