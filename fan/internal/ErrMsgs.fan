
@Js
internal class ErrMsgs {

	static Str typeCoercer_fail(Type from, Type to) {
		stripSys("Could not coerce ${from.qname} to ${to.qname}")
	}
	
	static Str typeCoercer_notFound(Type? from, Type to) {
		stripSys("Could not find coercion from ${from?.qname} to ${to.signature}")
	}
	
	static Str property_badParse(Str input) {
		"Could not parse property string: ${input}"
	}

	static Str property_crazyList(Int index, Type listType) {
		stripSys("Are you CRAZY!? Do you *really* want to create ${index} instances of ${listType}??? \nSee ${BeanPropertyFactory#maxListSize.qname} to change this limit, or create them yourself.")
	}

	static Str property_setOnMethod(Method method) {
		stripSys("Can not *set* a value on method: ${method.qname}")
	}

	static Str property_notMethod(Field field) {
		stripSys("Can not pass method arguments to a field: ${field.qname}")
	}

	static Str factory_defValNotFound(Type type) {
		stripSys("Could not find a default value for ${type.signature}")
	}

	static Str factory_ctorWrongType(Type type, Method ctor) {
		stripSys("Ctor ${ctor.qname} does not belong to $type.qname")
	}

	static Str factory_ctorArgMismatch(Method ctor, Obj?[] args) {
		ctorSig := ctor.qname + "(" + ctor.params.join(", ") + ")"
		return stripSys("Arguments do not match ctor params for ${ctorSig} - ${args}")
	}

	static Str factory_noCtorsFound(Type type, Type?[] argTypes) {
		stripSys("Could not find a ctor on ${type.qname} to match argument types - ${argTypes}")
	}

	static Str factory_tooManyCtorsFound(Type type, Str[] ctorNames, Type?[] argTypes) {
		stripSys("Found more than 1 ctor on ${type.qname} ${ctorNames} that match argument types - ${argTypes}")
	}

	private static Str stripSys(Str str) {
		str.replace("sys::", "")
	}
}
