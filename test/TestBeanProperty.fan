
internal class TestBeanProperty : BeanTest {
	
	Int? 			basic
	Int[]?			list
	Int?[]?			listNull
	[Str:Str]?		map1
	[Int:Int]?		map2
	[Str:T_Obj01]?	map3
	T_Obj01?		obj
	Str				judge() { "Dredd" }
	Str				add(Int x, Int y, Int a := -1) { "$x + $y = $a" }
	T_Obj01?		obj2() { obj }

	@Operator
	T_Obj01? get(Str key) { 
		if (map3 == null)
			map3 = [:]
		return map3[key] 
	}

	@Operator
	Void set(Str key, T_Obj01 val) { map3[key] = val }

	Void testBasic() {
		prop := BeanProperty(TestBeanProperty#, "basic")
		
		// test normal
		prop.set(this, 69)
		verifyEq(basic, 69)
		verifyEq(prop.get(this), 69)
		
		// test type coercion
		prop.set(this, "42")
		verifyEq(basic, 42)
		verifyEq(prop.get(this), 42)
	}
	
	Void testList() {
		prop := BeanProperty(TestBeanProperty#, "list[0]")
		list = [,]

		// test normal
		prop.set(this, 69)
		verifyEq(list[0], 69)
		verifyEq(prop.get(this), 69)
		
		// test another
		BeanProperty(TestBeanProperty#, "list[1]").set(this, 3)
		verifyEq(list[1], 3)
		
		// test type coercion
		prop.set(this, "42")
		verifyEq(list[0], 42)
		verifyEq(prop.get(this), 42)
	}

	Void testMap() {
		prop1 := BeanProperty(TestBeanProperty#, "map1[wot]")
		prop2 := BeanProperty(TestBeanProperty#, "map2[6]")
		map1 = [:]
		map2 = [:]

		// test normal
		prop1.set(this, "ever")
		verifyEq(map1["wot"], "ever")
		verifyEq(prop1.get(this), "ever")
		
		// test another
		BeanProperty(TestBeanProperty#, "map1[tough]").set(this, "man")
		verifyEq(map1["tough"], "man")
		
		// test type coercion
		prop2.set(this, 9)
		verifyEq(map2[6], 9)
		verifyEq(prop2.get(this), 9)
	}
	
	Void testObjCreation() {
		prop := BeanProperty(TestBeanProperty#, "obj.str")
		prop.set(this, "hello")
		verifyEq(this.obj.str, "hello")
		verifyEq(prop.get(this), "hello")
	}

	Void testListCreation() {
		prop := BeanProperty(TestBeanProperty#, "list[0]")
		prop.set(this, 69)
		verifyEq(list[0], 69)
		verifyEq(prop.get(this), 69)
	}
	
	Void testListIndexCreation() {
		prop := BeanProperty(TestBeanProperty#, "list[3]")
		prop.set(this, 69)
		verifyEq(list[3], 69)
		verifyEq(prop.get(this), 69)

		verifyEq(list[0], Int.defVal)
		verifyEq(list[1], Int.defVal)
		verifyEq(list[2], Int.defVal)
		verifyEq(list.size, 4)

		prop = BeanProperty(TestBeanProperty#, "list[5]")
		prop.set(this, 42)
		verifyEq(list[4], Int.defVal)
		verifyEq(list[5], 42)
		verifyEq(list.size, 6)

		prop = BeanProperty(TestBeanProperty#, "list[10006]")
		verifyErrMsg(ArgErr#, ErrMsgs.property_crazy(10006, Int#, TestBeanProperty#list)) {
			prop.set(this, 6)			
		}
	}

	Void testListIndexNullCreation() {
		prop := BeanProperty(TestBeanProperty#, "listNull[2]")
		prop.set(this, 69)
		verifyEq(listNull[0], null)
		verifyEq(listNull[1], null)
		verifyEq(listNull[2], 69)
		verifyEq(listNull.size, 3)
	}
	
	Void testMapCreation() {
		prop := BeanProperty(TestBeanProperty#, "map1[wot]")
		prop.set(this, "ever")
		verifyEq(map1["wot"], "ever")
		verifyEq(prop.get(this), "ever")
	}

	Void testMapValueCreation() {
		prop := BeanProperty(TestBeanProperty#, "map3[wot].str")
		prop.set(this, "ever")
		verifyEq(map3["wot"].str, "ever")
		verifyEq(prop.get(this), "ever")
	}
	
	Void testNested() {
		prop := BeanProperty(TestBeanProperty#, "obj.list[1].map[wot].str")
		prop.set(this, "ever")
		verifyEq(obj.list[1].map["wot"].str, "ever")
		verifyEq(prop.get(this), "ever")
	}

	Void testGetSetOperators() {
		prop := BeanProperty(TestBeanProperty#, "obj[wot].str")
		prop.set(this, "ever")
		verifyEq(obj["wot"].str, "ever")
		verifyEq(prop.get(this), "ever")

		// test @Op getter following a method 
		prop = BeanProperty(TestBeanProperty#, "obj2[wot].str")
		prop.set(this, "blah")
		verifyEq(obj2["wot"].str, "blah")
		verifyEq(prop.get(this), "blah")

		prop = BeanProperty(TestBeanProperty#, "[woot].str")
		prop.set(this, "ever")
		verifyEq(get("woot").str, "ever")
		verifyEq(prop.get(this), "ever")
	}
	
	Void testMethod() {
		prop := BeanProperty(TestBeanProperty#, "judge")
		verifyEq(prop.get(this), "Dredd")
		verifyErrMsg(ArgErr#, ErrMsgs.property_setOnMethod(#judge)) {
			prop.set(this, "Anderson")
		}

		prop = BeanProperty(TestBeanProperty#, "judge()")
		verifyEq(prop.get(this), "Dredd")
		verifyErrMsg(ArgErr#, ErrMsgs.property_setOnMethod(#judge)) {
			prop.set(this, "Dredd")			
		}
	}
	
	Void testMethodArgs() {
		prop := BeanProperty(TestBeanProperty#, "add(1, 2, 3)")
		verifyEq(prop.get(this), "1 + 2 = 3")

		prop = BeanProperty(TestBeanProperty#, "add(1, 2)")
		verifyEq(prop.get(this), "1 + 2 = -1")
	}

	Void testMethodNested() {
		prop := BeanProperty(TestBeanProperty#, "obj.list[2].map[wot].meth(dredd).str")
		verifyEq(prop[this], "dredd")
	}
}

internal class T_Obj01 {
	Str? 			str
	T_Obj01[]?		list
	[Str:T_Obj01]?	map
	[Str:T_Obj01?]	map2 := [:]
	
	T_Obj01	meth(Str str) { T_Obj01().with { it.str = str } }
	
	@Operator
	T_Obj01? get(Str key) {
		return map2[key]
	}

	@Operator
	Void set(Str key, T_Obj01 val) {
		map2[key] = val
	}
}

