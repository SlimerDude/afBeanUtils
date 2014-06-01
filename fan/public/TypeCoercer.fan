
** Coerces objects to a given type via 'fromXXX()' / 'toXXX()' ctors and methods.
** This is often useful for converting objects to and from Strs, but can be used for much more. 
** 
** 'TypeCoercer' inspects type parameters in Lists and Maps and also converts the contents of each.
** Example, coercing 'Int[1, 2, 3]' to 'Str[]' will convert each item of the list into a Str.
** Similarly, when coercing a map to a new map type, all the key and vals will be converted.   
** 
** The 'caseInsensitive' and 'ordered' attributes of new maps are preserved.
** 
** If performance is required, then use [Concurrent]`http://www.fantomfactory.org/pods/afConcurrent` 
** to create a 'TypeCoercer' that caches the functions used to convert between one type and another. 
** Full code for a 'CachingTypeCoercer' is given below: 
** 
** pre>
** using afBeanUtils
** using afConcurrent
** 
** ** A 'TypeCoercer' that caches its conversion methods.
** const class CachingTypeCoercer : TypeCoercer {
**    private const AtomicMap cache := AtomicMap()
** 
**    ** Cache the conversion functions
**    override protected |Obj->Obj|? createCoercionFunc(Type fromType, Type toType) {
**       key := "${fromType.qname}->${toType.qname}"
**       return cache.getOrAdd(key) { doCreateCoercionFunc(fromType, toType) } 
**    }
** 
**    ** Clears the function cache 
**    Void clear() {
**       cache.clear
**    }
** }
** <pre
const class TypeCoercer {
	
	** Returns 'true' if 'fromType' can be coerced to the given 'toType'.
	Bool canCoerce(Type fromType, Type toType) {
		if (fromType.name == "List" && toType.name == "List") {
			valFunc := createCoercionFunc(fromType.params["V"] ?: Obj?#, toType.params["V"] ?: Obj?#) 
			return valFunc != null
		}

		if (fromType.name == "Map" && toType.name == "Map") {
			keyFunc := createCoercionFunc(fromType.params["K"] ?: Obj#,  toType.params["K"] ?: Obj#) 
			valFunc := createCoercionFunc(fromType.params["V"] ?: Obj?#, toType.params["V"] ?: Obj?#) 
			return keyFunc != null && valFunc != null
		}

		return createCoercionFunc(fromType, toType) != null
	}
	
	** Coerces the Obj to the given type. 
	** Coercion methods are looked up in the following order:
	**  1. 'toXXX()'
	**  2. 'fromXXX()'
	**  3. 'makeFromXXX()' 
	Obj? coerce(Obj? value, Type toType) {
		if (value == null) 
			return toType.isNullable ? null : throw ArgErr(ErrMsgs.typeCoercer_notFound(null, toType))

		if (value.typeof.name == "List" && toType.name == "List") {
			toListType 	:= toType.params["V"] ?: Obj?#
			toList 		:= (Obj?[]) toListType.emptyList.rw
			((List) value).each {
				toList.add(coerce(it, toListType))
			}
			return toList
		}

		if (value.typeof.name == "Map" && toType.name == "Map") {
			toKeyType := toType.params["K"] ?: Obj#
			toValType := toType.params["V"] ?: Obj?#
			toMap	  := ([Obj:Obj?]?) null
			
			if (((Map) value).caseInsensitive && toKeyType.fits(Str#))
				toMap	 = Map.make(toType) { caseInsensitive = true }
			if (((Map) value).ordered)
				toMap	 = Map.make(toType) { ordered = true }
			if (toMap == null)
				toMap	 = toType.isGeneric ? Map.make(Obj:Obj?#) : Map.make(toType)

			((Map) value).each |v1, k1| {
				k2	:= coerce(k1, toKeyType)
				v2	:= coerce(v1, toValType)
				toMap[k2] = v2
			}
			return toMap
		}

		meth := createCoercionFunc(value.typeof, toType)
		
		if (meth == null)
			throw ArgErr(ErrMsgs.typeCoercer_notFound(value.typeof, toType))

		try {
			return meth(value)
		} catch (Err e) {
			throw ArgErr(ErrMsgs.typeCoercer_fail(value.typeof, toType), e)
		}
	}
	
	** Override this method should you wish to cache the conversion functions. 
	** 
	** @see http://fantom.org/sidewalk/topic/2289
	@NoDoc
	protected virtual |Obj->Obj|? createCoercionFunc(Type fromType, Type toType) {
		doCreateCoercionFunc(fromType, toType)
	}

	** It kinda sucks to need this method, but it's a workaround to 
	** [this issue]`http://fantom.org/sidewalk/topic/2289`.
	@NoDoc
	protected |Obj->Obj|? doCreateCoercionFunc(Type fromType, Type toType) {
		// check the basics first!
		if (fromType.fits(toType))
			return |Obj val -> Obj| { val }

		// first look for a 'toXXX()' instance method
		toName		:= "to${toType.name}" 
		toXxxMeth 	:= ReflectUtils.findMethod(fromType, toName, Obj#.emptyList, false, toType)
		if (toXxxMeth != null)
			return |Obj val -> Obj| { toXxxMeth.callOn(val, null) }

		// next look for a 'fromXXX()' static / ctor
		// see http://fantom.org/sidewalk/topic/2154
		fromName	:= "from${fromType.name}" 
		fromXxxMeth	:= ReflectUtils.findMethod(toType, fromName, [fromType], true)
		if (fromXxxMeth != null)
			return (|Obj val -> Obj| { fromXxxMeth.call(val) }).toImmutable
		fromXxxCtor := ReflectUtils.findCtor(toType, fromName, [fromType])
		if (fromXxxCtor != null)
			return (|Obj val -> Obj| { fromXxxCtor.call(val) }).toImmutable
				
		// one last chance - try 'makeFromXXX()' ctors
		makefromName	:= "makeFrom${fromType.name}" 
		makeFromXxxMeth	:= ReflectUtils.findMethod(toType, makefromName, [fromType], true)
		if (makeFromXxxMeth != null)
			return |Obj val -> Obj| { makeFromXxxMeth.call(val) }
		makeFromXxxCtor := ReflectUtils.findCtor(toType, makefromName, [fromType])
		if (makeFromXxxCtor != null)
			return |Obj val -> Obj| { makeFromXxxCtor.call(val) }
		
		return null
	}
}
