
// FIXME: fandoc this! 
@Js
class BeanProperties {

	// Bad idea, static values are const! (Okay, well, thread safe - but they rarely change anyhow.)
	// static Obj getStaticProperty(Type type, Str property) { ... }
	
	** Similar to 'get()' but may read better in code if you know the expression ends with a method.
	** 
	** Any arguments given overwrite arguments in the expression. Example:
	** 
	**   BeanProperties.call(Buf(), "fill(255, 4)", [128, 2])  // --> 0x8080
	static Obj? call(Obj instance, Str property, Obj?[]? args := null) {
		BeanPropertyFactory().parse(property).call(instance, args)
	}

	** Gets the value of the field (or method) at the end of the property expression.
	static Obj? get(Obj instance, Str property) {
		BeanPropertyFactory().parse(property).get(instance)
	}
	
	** Sets the value of the field at the end of the property expression.
	static Void set(Obj instance, Str property, Obj? value) {
		BeanPropertyFactory().parse(property).set(instance, value)
	}
	
	** Given a map of values, keyed by property expressions, this sets them on the given instance.
	** 
	** Returns the given instance.
	static Obj setAll(Obj instance, Str:Obj? propertyValues) {
		factory := BeanPropertyFactory()
		propertyValues.each |value, property| {
			factory.parse(property).set(instance, value)
		}
		return instance
	}
	
	// TODO: 
//	static Obj setAllFromHtmlForm(Obj instance, Str:Obj? propertyValues) {
//		
//	}
}

** Parses property expressions to create 'BeanProperty' instances. 
@Js @NoDoc
class BeanPropertyFactory {
	
	// Fantex test string: obj.list[2].map[wot][thing].meth(judge, dredd).str().prop
	private static const Regex	slotRegex	:= Regex<|(?:([^\.\[\]\(\)]*)(?:\(([^\)]+)\))?)?(?:\[([^\]]+)\])?|>
	
	** Given to 'BeanProperties' to convert Str values into objects. 
	** Supplied so you may substitute it with a cached version. 
	TypeCoercer 	typeCoercer	 := TypeCoercer()
	
	** Given to 'BeanProperties' to create new instances of intermediate objects.
	** Supplied so you may substitute it with one that injects IoC values.
	** 
	** Only used if 'createIfNull' is 'true'. 
	** 
	** Defaults to '|Type type->Obj| { BeanFactory.defaultValue(type) }'
	|Type->Obj|		makeFunc 	 := |Type type->Obj| { BeanFactory.defaultValue(type) }

	** Given to 'BeanProperties' to indicate if they should create new object instances when traversing an expression.
	** If an a new instance is *not* created then a 'NullErr' will occur.
	** 
	** For example, in the expression 'a.b.c', should 'b' be null then a new instance is created and set. 
	** This also applies when setting instances in a 'List' where the List size is less than the index.
	** 
	** Defaults to 'true' 
	Bool			createIfNull := true
	
	** Given to 'BeanProperties' to limit how may list items it may create for any given list.
	** If it attempts to grow a list greater than this size then an Err is raised.
	** 
	** Defaults to '10,000'. 
	** 
	** Automatically creating 1000 items is mad, but 10,000 is *insane*!
	Int				maxListSize	:= 10000
	
	** Parses a property expression stemming from the given type to produce a 'BeanProperty' that can be used to get / set / call the value at the end. 
	BeanProperty parse(Str property) {
		beanSlots	:= SegmentFactory[,]

		matcher	:= slotRegex.matcher(property)
		while (matcher.find) {
			if (matcher.group(0).isEmpty) {
				continue
			}

			slotName	:= matcher.group(1)
			methodArgs	:= matcher.group(2)?.split(',', true)
			indexName	:= matcher.group(3)
			beanSlot 	:= (SegmentFactory?) null

			if (!slotName.isEmpty)
				beanSlots.add(SlotSegment(slotName, methodArgs) { 
					it.typeCoercer	= this.typeCoercer
					it.createIfNull	= this.createIfNull
					it.makeFunc 	= this.makeFunc 
				})

			if (indexName != null)
				beanSlots.add(IndexSegment(indexName) { 
					it.typeCoercer	= this.typeCoercer
					it.createIfNull	= this.createIfNull
					it.makeFunc 	= this.makeFunc 
					it.maxListSize	= this.maxListSize 
				})
		}

		if (beanSlots.isEmpty)
			throw Err(ErrMsgs.property_badParse(property))		

		return BeanProperty(property, beanSlots)
	}
}

** Calls methods and gets and sets fields at the end of a property expression.
** Property expressions may traverse lists, maps and methods.
** All field are accessed through their respective getter and setters.
** 
** Use `BeanPropertyFactory` to create instances of 'BeanProperty'.
@Js @NoDoc
const class BeanProperty {
	
	** The property expression that this class ultimately calls. 
	const Str expression

	private const SegmentFactory[] segments
	
	internal new make(Str expression, SegmentFactory[] segments) {
		this.expression = expression
		this.segments	= segments
	}

	** Similar to 'get()' but may read better in code if you know the expression ends with a method.
	** 
	** Any arguments given overwrite arguments in the expression. Example:
	** 
	**   BeanProperties.call(Buf(), "fill(255, 4)", [128, 2])  // --> 0x8080
	Obj? call(Obj instance, Obj?[]? args := null) {
		callChain(instance).get(args)
	}
	
	** Gets the value of the field (or method) at the end of the property expression.
	@Operator
	Obj? get(Obj instance) {
		callChain(instance).get(null)
	}
	
	** Sets the value of the field at the end of the property expression.
	@Operator
	Void set(Obj instance, Obj? value) {
		callChain(instance).set(value)
	}
	
	private SegmentExecutor callChain(Obj instance) {
		staticType := instance.typeof
		segments.eachRange(0..<-1) |bean| {
			segment 	:= bean.makeSegment(staticType, instance, false)
			instance 	= segment.get(null) 
			staticType	= segment.returns
		}
		return segments[-1].makeSegment(staticType, instance, true)
	}
}
