
internal const abstract class SegmentFactory {
	const TypeCoercer	typeCoercer
	const |Type->Obj?|	makeFunc
	const Bool			createIfNull
	
	new make(|This| f) { f(this) }

	abstract SegmentExecutor	makeSegment(Type parentType, Obj? parentInstance, Bool isLast)
	abstract SegmentType 		type(Type parentType)
	abstract Str 				expression()
}

internal enum class SegmentType {
	field, method, index
}

internal const class SlotSegment : SegmentFactory {
	const Str?[]	methodArgs
	const Str 		slotName
	
	new make(Str slotName, Str[]? methodArgs, |This| f) : super(f) {
		this.slotName 	= slotName
		this.methodArgs = methodArgs ?: Str#.emptyList
	}

	override SegmentExecutor makeSegment(Type parentType, Obj? parentInstance, Bool isLast) {
		slot := parentInstance?.typeof?.slot(slotName) ?: parentType.slot(slotName)
		
		if (slot.isField)
			return ExecuteField(parentInstance, slot) {
				it.typeCoercer 	= this.typeCoercer
				it.createIfNull	= isLast ? false : this.createIfNull
				it.makeFunc		= this.makeFunc
			}

		if (slot.isMethod)
			return ExecuteMethod(parentInstance, slot, methodArgs) {
				it.typeCoercer 	= this.typeCoercer
				it.createIfNull	= isLast ? false : this.createIfNull
				it.makeFunc		= this.makeFunc
			}

		throw Err("WTF!?")
	}
	
	override SegmentType type(Type parentType) {
		parentType.slot(slotName).isField ? SegmentType.field : SegmentType.method 
	}
	
	override Str expression() {
		methodArgs.isEmpty ? slotName : "${slotName}(" + methodArgs.join(",") + ")"
	}

	override Str toStr() { expression }
}

internal const class IndexSegment : SegmentFactory {
	const Int	maxListSize
	const Str	index

	new make(Str index, |This| f) : super(f) {
		this.index	= index
	}

	override SegmentExecutor makeSegment(Type staticType, Obj? instance, Bool isLast) {
		ExecuteIndex(staticType, instance, index) {
			it.typeCoercer 	= this.typeCoercer
			it.createIfNull	= isLast ? false : this.createIfNull
			it.makeFunc		= this.makeFunc
			it.maxListSize	= this.maxListSize
		}
	}

	override SegmentType type(Type parentType) {
		SegmentType.index
	}

	override Str expression() {
		"[${index}]"
	}
	
	override Str toStr() { expression }
}

// ---- Executors ---------------------------------------------------------------------------------
internal abstract class SegmentExecutor {
	TypeCoercer?	typeCoercer
	|Type->Obj?|?	makeFunc 
	Bool?			createIfNull
	Obj?			instance

	abstract Obj? get(Obj?[]? args)
	abstract Void set(Obj? value)
	abstract Type returns()
}

internal class ExecuteField : SegmentExecutor {
	Field		field
	
	new make(Obj? instance, Field field, |This| f) {
		f(this)
		this.instance	= instance
		this.field		= field
	}
	
	override Obj? get(Obj?[]? args) {
		if (args != null)
			throw ArgErr("Can not pass method arguments to a field: ${field.qname}".replace("sys::", ""))

		ret := field.get(instance) 
		if (createIfNull && ret == null) {
			ret = makeFunc(field.type)
			field.set(instance, ret)
		}
		return ret
	}

	override Void set(Obj? value) {
		field.set(instance, coerceValue(value))
	}
	
	Obj? coerceValue(Obj? value) {
		typeCoercer.coerce(value, field.type)
	}
	
	override Type returns() {
		field.type
	}
}

internal class ExecuteMethod : SegmentExecutor {
	Method		method
	Str[]		methodArgs
	
	new make(Obj? instance, Method method, Str[] methodArgs, |This| f) {
		f(this)
		this.instance	= instance
		this.method		= method
		this.methodArgs	= methodArgs
	}
	
	override Obj? get(Obj?[]? args) {
		args = args ?: methodArgs.map |arg, i| { typeCoercer.coerce(arg, method.params[i].type) }
		ret := method.callOn(instance, args)
		return ret
	}

	override Void set(Obj? value) {
		throw ArgErr("Can not *set* a value on method: ${method.qname}".replace("sys::", ""))
	}

	override Type returns() {
		method.returns
	}
}

internal class ExecuteIndex : SegmentExecutor {
	Int			maxListSize
	Str			index
	Method		getMethod
	Method		setMethod
	Type		idxType
	Type		valType
	Bool		isList

	new make(Type staticType, Obj? instance, Str index, |This| f) {
		f(this)
		type			:= instance?.typeof ?: staticType
		this.isList		= false
		this.instance	= instance
		this.index		= index
		this.getMethod	= type.method("get") 
		this.setMethod	= type.method("set")
		if (type.name == "List") {
			this.isList		= true
			this.idxType 	= Int#
			this.valType 	= mostSpecific(type, staticType, "V")
		} else
		if (type.name == "Map") {
			this.idxType 	= mostSpecific(type, staticType, "K")
			this.valType 	= mostSpecific(type, staticType, "V")
		}
		else {
			this.idxType 	= getMethod.params.first.type
			this.valType	= getMethod.returns			
		}
	}
	
	override Obj? get(Obj?[]? args) {
		idx := typeCoercer.coerce(index, idxType)
		
		// if in the middle of an expression, ensure we succeed
		if (isList && createIfNull)
			ensureListSize(instance, idx)
		
		ret := getMethod.callOn(instance, [idx])
		
		// don't return null in the middle of an expression
		if (createIfNull && ret == null) {
			ret = makeFunc(valType)
			setMethod.callOn(instance, [idx, ret])
		}
		return ret
	}
	
	override Void set(Obj? value) {
		idx := typeCoercer.coerce(index, idxType)
		if (isList)
			ensureListSize(instance, idx)
		val := typeCoercer.coerce(value, valType)
		setMethod.callOn(instance, [idx, val])
	}
	
	override Type returns() {
		valType
	}

	** The problem with dynamic inspection is that Lists and Maps are not always what they're declared to be! 
	** Consider:
	** 
	**   Int:Int map() { [:] } // --> bad, returns Obj:Obj? !!!
	** 
	** Which means we'll actually create a key of Obj and not Int! 
	** So we keep track of the last statically declared return type and choose which ever one appears more specific.
	** 
	** Very clever!
	private Type mostSpecific(Type type1, Type type2, Str param) {
		pType1 	:= type1.params[param] ?: Obj?#
		pType2 	:= type2.params[param] ?: Obj?#
		return pType1.fits(pType2) ? pType1 : pType2
	}
	
	private Void ensureListSize(Obj?[] list, Int idx) {
		if (list.size <= idx) {
			if (idx > maxListSize)
				throw ArgErr(property_crazyList(idx, valType, BeanPropertyFactory#maxListSize))
			if (valType.isNullable)
				list.size = idx + 1
			else {
				if (list.capacity < (idx + 1))
					list.capacity = idx + 1
				toAdd := idx - list.size + 1
				toAdd.times { list.add(makeFunc(valType)) }
			}
		}
	}
	
	static Str property_crazyList(Int index, Type listType, Field field) {
		"Are you CRAZY!? Do you *really* want to create ${index} instances of ${listType}??? \nSee ${field.qname} to change this limit, or create them yourself".replace("sys::", "")
	}
}
