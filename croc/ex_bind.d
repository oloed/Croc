/******************************************************************************
This module contains scary template stuff to make it possible to wrap D functions,
classes, and structs and expose them as functions and types in Croc.

This binding library is not supposed to be the most flexible or capable. For
example, its class wrapping is meant to be usable with classes to whose source
code you don't necessarily have access to, or whose code you can't change (like
in third-party libraries). This library has to sacrifice some efficiency and
capabilities to be able to do this. 

However, if you're really only concerned with integrating your $(I own) code with
Croc, something like $(LINK2 xpose http://team0xf.com:8080/xf/file/37d8e57b1c4d/xpose/)
might be more appropriate. Xpose allows you to add reflection info to your types
which you can then use to make bindings to Croc.

License:
Copyright (c) 2008 Jarrett Billingsley

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the
use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it freely,
subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
	claim that you wrote the original software. If you use this software in a
	product, an acknowledgment in the product documentation would be
	appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not
	be misrepresented as being the original software.

    3. This notice may not be removed or altered from any source distribution.
******************************************************************************/

module croc.ex_bind;

import tango.core.Traits;
import tango.core.Tuple;
import tango.text.convert.Utf;

alias tango.text.convert.Utf.toString Utf_toString;
alias tango.text.convert.Utf.toString16 Utf_toString16;
alias tango.text.convert.Utf.toString32 Utf_toString32;

import croc.api_interpreter;
import croc.api_stack;
import croc.ex;
import croc.types;
import croc.utils;
import croc.vm;

alias croc.utils.isArrayType isArrayType;

// ================================================================================================================================================
// Public
// ================================================================================================================================================

public:

/**
Wraps a module. This registers a custom module loader in the global modules.customLoaders
table of the given thread. The members will not actually be wrapped until the module is imported
the first time.

Template Params:
	name = The name of the module, in dotted form (like "foo.bar.baz"). This is the name that will
		be used to import it.

	Members = A variadic list of things to declare in this module. These will be declared as module
		globals, just as if you declared them globals in Croc. Supported member types include
		WrapFunc, WrapNamespace, WrapValue, and WrapType.

Params:
	t = This module's loader will be added into the global modules.customLoaders table accessible
		from this thread.
*/
void WrapModule(char[] name, Members...)(CrocThread* t)
{
	makeModule(t, name, function uword(CrocThread* t)
	{
		commonNamespace!(name, true, Members)(t);
		return 0;
	});
}

/**
Wraps any number of values into the global namespace accessible from the given thread. This is
the root global namespace, outside of any modules. Works just like WrapModule otherwise.
Supported member types include WrapFunc, WrapNamespace, WrapValue, and WrapType.

The wrapped values are immediately loaded into the global namespace.
*/
void WrapGlobals(Members...)(CrocThread* t)
{
	commonNamespace!("", true, Members)(t);
}

/**
Wraps a static function - that is, a function that doesn't have a 'this' parameter. These four
template specializations allow you to fine-tune how the function is to be wrapped.

The first specialization takes just an alias to a function. In this case, the first overload
of the function (if any) will be wrapped and the name of the function in Croc will be the same
as in D.

The second specialization allows you to explicitly specify a function signature to choose, in the
case that the function you're wrapping is overloaded. The signature should be a function type that
matches the signature of the overload you want to wrap. In this case, though, the name in Croc
will still be the name of the D function.

The third specialization allows you to rename the function without explicitly selecting an overload.

The fourth specialization allows you to both select an overload and give it the name that should
be used in Croc. This is the form you'll probably be using most often with overloaded D functions.

If you use one of the two forms where you explicitly specify the function signature, the resulting
wrapped function will only accept exactly as many parameters as are specified in the signature.
Otherwise, the wrapped function will be allowed to have optional parameters.
*/
struct WrapFunc(alias func)
{
	const bool isFunc = true;
	const char[] Name = NameOfFunc!(func);
	mixin WrappedFunc!(func, Name, typeof(&func), false);
}

/// ditto
struct WrapFunc(alias func, funcType)
{
	const bool isFunc = true;
	const char[] Name = NameOfFunc!(func);
	mixin WrappedFunc!(func, Name, funcType, true);
}

/// ditto
struct WrapFunc(alias func, char[] name)
{
	const bool isFunc = true;
	const char[] Name = name;
	mixin WrappedFunc!(func, Name, typeof(&func), false);
}

/// ditto
struct WrapFunc(alias func, char[] name, funcType)
{
	const bool isFunc = true;
	const char[] Name = name;
	mixin WrappedFunc!(func, Name, funcType, true);
}

/**
Wraps a bunch of values into a namespace object. This works virtually the same as WrapModule,
except that it's meant to be used as a member of something like WrapModule. Legal member
types include WrapFunc, WrapValue, WrapNamespace, and WrapType.
*/
struct WrapNamespace(char[] name, members...)
{
	const bool isNamespace = true;
	const char[] Name = name;
	alias members Values;
}

/**
Wraps a single value and gives it a name. Despite the fact that the value parameter is
variadic, it is restricted to exactly one item. It's variadic just so it can accept any
value type.
*/
struct WrapValue(char[] name, value...)
{
	static assert(Value.length == 1 && isExpressionTuple!(Value), "WrapValue - must have exactly one expression");
	const bool isValue = true;
	const char[] Name = name;
	alias value Value;
}

/**
Wraps a class or struct type. This supports wrapping constructors (or static opCall for structs),
methods, properties (though they will be $(B functions) in Croc), and arbitrary values. That means
the valid member types are WrapCtors, WrapMethod, WrapProperty, and WrapValue.

Template Params:
	Type = The class or struct type to be wrapped.

	name = The name that will be given to the type in Croc.

	Members = The members of the type.
	
Bugs:
	Abstract classes cannot be wrapped. D1 does not provide enough reflective information to do so reliably.
*/
struct WrapType(Type, char[] name = NameOfType!(Type), Members...)
{
	// Because it's pointless (and Croc has its own Object).
	static assert(!is(Type == Object), "Wrapping Object is not allowed");
	static assert(is(Type == class) || is(Type == struct), "Cannot wrap type " ~ Type.stringof);

private:
	const bool isType = true;
	const char[] Name = name;

	static word init(char[] moduleName)(CrocThread* t)
	{
		checkInitialized(t);

		// Check if this type has already been wrapped
		getWrappedClass(t, typeid(Type));

		if(!isNull(t, -1))
			throwStdException(t, "Exception", "Native type " ~ NameOfType!(Type) ~ " cannot be wrapped more than once");

		pop(t);
		
		// Wrap it
		static if(is(Type == class))
			WrappedClass!(Type, name, moduleName, Members).init(t);
		else
			WrappedStruct!(Type, name, moduleName, Members).init(t);

		// Set the allocator
		newFunction(t, &classAllocator, name ~ ".allocator");
		setAllocator(t, -2);

		// Set the class
		setWrappedClass(t, typeid(Type));
		return stackSize(t) - 1;
	}

	static uword classAllocator(CrocThread* t)
	{
		newInstance(t, 0, 1);

		dup(t);
		pushNull(t);
		rotateAll(t, 3);
		methodCall(t, 2, "constructor", 0);
		return 1;
	}
}

/**
D doesn't really provide any facilities for introspecting class constructors, so you'll have to specify
to the binding library the signatures of the constructors to expose. You'll also have to do it for structs.
There can be at most one WrapCtors inside a WrapType, but since you specify as many constructors as you
want all at once, it doesn't matter. The constructor signatures should be function types; the return type
is ignored, and only the parameter types are significant.

Unlike wrapping other functions, a form of overloading is allowed for constructors. That is, you can have
a constructor that takes (int) and another that takes (float), wrap them as two separate types, and they
will be correctly dispatched when the type is instantiated in Croc. This also means that the usual
implicit conversion from int to float that happens when calling other functions will not happen when calling
constructors.
*/
struct WrapCtors(T...)
{
	static assert(T.length > 0, "WrapCtors must be instantiated with at least one type");
	const bool isCtors = true;
	alias Unique!(QSort!(SortByNumParams, T)) Types;
}

/**
Wraps a method of a class or struct type. The argument to this template will look like "A.foo" for a given
type "A". Other than the fact that it's a method (and therefore takes 'this'), this works pretty much
exactly the same as WrapFunction, including the differences between the multiple specializations.
*/
struct WrapMethod(alias func)
{
	const bool isMethod = true;
	const char[] Name = NameOfFunc!(func);
	const bool explicitType = false;
	alias func Func;
	alias typeof(&func) FuncType;
}

/// ditto
struct WrapMethod(alias func, char[] name)
{
	const bool isMethod = true;
	const char[] Name = name;
	const bool explicitType = false;
	alias func Func;
	alias typeof(&func) FuncType;
}

/// ditto
struct WrapMethod(alias func, funcType)
{
	const bool isMethod = true;
	const char[] Name = NameOfFunc!(func);
	const bool explicitType = true;
	alias func Func;
	alias funcType FuncType;
}

/// ditto
struct WrapMethod(alias func, char[] name, funcType)
{
	const bool isMethod = true;
	const char[] Name = name;
	const bool explicitType = true;
	alias func Func;
	alias funcType FuncType;
}

/**
Wraps a D "property."  D of course does not have real properties but only syntactic sugar for function
calls. These wrap a pair of functions (or just one function, if the property is read-only) that denote
a property. In Croc, each property has a method named "_prop_name" which does the actual setting and
getting, and the wrapped type is given opField and opFieldAssign metamethods which dispatch field access
to the appropriate property accessors. If you want to override the behavior of setting/getting a property,
you can do so by overriding the "_prop_name" method.

The D "property" must be one or two functions (either just a getter or a getter/setter pair). The setter,
if any exists, must be able to take one parameter that is the same type as the getter's return type.
The setter may optionally return a value.

It doesn't matter whether you pass an alias to the setter or the getter to this; the library will figure
out which one you gave and which one it needs. So if you have a property "x" of a type "A", it'll just
be WrapProperty!(A.x).

Since this is another variety of function wrapping, the parameters here all do the same thing as for
WrapFunction and WrapMethod.

Bugs:
	Currently overridden setters/getters are not called polymorphically and therefore will not be called
	by D code accessing the properties.
*/
struct WrapProperty(alias func)
{
	const bool isProperty = true;
	const char[] Name = NameOfFunc!(func);
	const char[] DName = NameOfFunc!(func);
	const bool readOnly = ReadOnly!(func, typeof(&func));
	alias PropType!(func, typeof(&func)) propType;
}

/// ditto
struct WrapProperty(alias func, char[] name)
{
	const bool isProperty = true;
	const char[] Name = name;
	const char[] DName = NameOfFunc!(func);
	const bool readOnly = ReadOnly!(func, typeof(&func));
	alias PropType!(func, typeof(&func)) propType;
}

/// ditto
struct WrapProperty(alias func, funcType)
{
	const bool isProperty = true;
	const char[] Name = NameOfFunc!(func);
	const char[] DName = NameOfFunc!(func);
	const bool readOnly = ReadOnly!(func, funcType);
	alias PropType!(func, funcType) propType;
}

/// ditto
struct WrapProperty(alias func, char[] name, funcType)
{
	const bool isProperty = true;
	const char[] Name = name;
	const char[] DName = NameOfFunc!(func);
	const bool readOnly = ReadOnly!(func, funcType);
	alias PropType!(func, funcType) propType;
}

/**
Given a TypeInfo instance of the desired class/struct type (that is, typeid(SomeType)), pushes
the corresponding wrapped Croc class, or pushes null if the type has not been wrapped.

$(B You probably won't have to call this function under normal circumstances.)

Params:
	ti = The runtime TypeInfo instance of the desired type.

Returns:
	The stack index of the newly-pushed value.
*/
word getWrappedClass(CrocThread* t, TypeInfo ti)
{
	if(auto tic = cast(TypeInfo_Class)ti)
		return getWrappedClass(t, tic.info);
	else
	{
		getRegistryVar(t, "croc.bind.WrappedClasses");
		pushNativeObj(t, ti);

		if(!opin(t, -1, -2))
		{
			pop(t, 2);
			return pushNull(t);
		}

		idx(t, -2);
		insertAndPop(t, -2);
		return stackSize(t) - 1;
	}
}

/**
Given a ClassInfo instance of the desired class type, pushes
the corresponding wrapped Croc class, or pushes null if the type has not been wrapped.

$(B You probably won't have to call this function under normal circumstances.)

Params:
	ci = The runtime ClassInfo instance of the desired class.

Returns:
	The stack index of the newly-pushed value.
*/
word getWrappedClass(CrocThread* t, ClassInfo ci)
{
	getRegistryVar(t, "croc.bind.WrappedClasses");
	pushNativeObj(t, ci);

	if(!opin(t, -1, -2))
	{
		pop(t, 2);
		return pushNull(t);
	}

	idx(t, -2);
	insertAndPop(t, -2);
	return stackSize(t) - 1;
}

/**
Given a ClassInfo instance of the desired class type, pushes
the corresponding wrapped Croc class, or pushes null if the type has not been wrapped.
This version looks for a super class if a direct match cannot be found.

$(B You probably won't have to call this function under normal circumstances.)

Params:
	ci = The runtime ClassInfo instance of the desired class.

Returns:
	The stack index of the newly-pushed value.
*/
word getWrappedClassOrSuper(CrocThread* t, ClassInfo ci)
{
	getRegistryVar(t, "croc.bind.WrappedClasses");

	while(ci !is Object.classinfo && ci !is null)
	{
		pushNativeObj(t, ci);

		if(opin(t, -1, -2))
		{
			idx(t, -2);
			insertAndPop(t, -2);
			return stackSize(t) - 1;
		}
		else
		{
			pop(t);
			ci = ci.base;
		}
	}

	pop(t);
	return pushNull(t);
}

/**
Expects a class object on top of the stack, and sets it to be the Croc class that corresponds
to the given runtime TypeInfo object. The class object is $(B not) popped off the stack.

$(B You probably won't have to call this function under normal circumstances.)
*/
void setWrappedClass(CrocThread* t, TypeInfo ti)
{
	if(auto tic = cast(TypeInfo_Class)ti)
		return setWrappedClass(t, tic.info);
	else
	{
		getRegistryVar(t, "croc.bind.WrappedClasses");
		pushNativeObj(t, ti);
		dup(t, -3);
		idxa(t, -3);
		pop(t);
	}
}

/**
Expects a class object on top of the stack, and sets it to be the Croc class that corresponds
to the given runtime ClassInfo object. The class object is $(B not) popped off the stack.

$(B You probably won't have to call this function under normal circumstances.)
*/
void setWrappedClass(CrocThread* t, ClassInfo ci)
{
	getRegistryVar(t, "croc.bind.WrappedClasses");
	pushNativeObj(t, ci);
	dup(t, -3);
	idxa(t, -3);
	pop(t);
}

/**
Assuming a valid wrapped class is on the top of the stack, this function will take a D object
and push the corresponding Croc instance. If a Croc instance has already been created for
this object, pushes that instance; otherwise, this will create an instance and link it to this
D object. The class is popped off, meaning the wrapped instance takes its place.

$(B You probably won't have to call this function under normal circumstances.)

Params:
	o = The D object to convert to a Croc instance.

Returns:
	The stack index of the newly-pushed instance.
*/
word getWrappedInstance(CrocThread* t, Object o)
{
	// TODO: change this to use a weak value table
	getRegistryVar(t, "croc.bind.WrappedInstances");
	pushNativeObj(t, o);
	idx(t, -2);
	deref(t, -1);

	if(isNull(t, -1))
	{
		pop(t, 2);

		newInstance(t, -2, 1);
		pushNativeObj(t, o);
		setExtraVal(t, -2, 0);

		pushNativeObj(t, o);
		pushWeakRef(t, -2);
		idxa(t, -4);

		insertAndPop(t, -3);
	}
	else
		insertAndPop(t, -4);

	return stackSize(t) - 1;
}

/**
For a given D object instance, sets the Croc instance at the given stack index to be
its corresponding object. 

$(B You probably won't have to call this function under normal circumstances.)

Params:
	o = The D object that should be linked to the given Croc instance.
	idx = The stack index of the Croc instance that should be linked to the given D object.
*/
void setWrappedInstance(CrocThread* t, Object o, word idx)
{
	getRegistryVar(t, "croc.bind.WrappedInstances");
	pushNativeObj(t, o);
	pushWeakRef(t, idx);
	idxa(t, -3);
	pop(t);
}

/**
Checks that the 'this' parameter passed to a native function is an instance of the given struct
type, and returns a pointer to the struct object that is referenced by 'this'.

Template Params:
	Type = The D struct type that corresponds to 'this'.

	FullName = The name of the type in Croc, in dotted form.

Returns:
	A pointer to the struct object referenced by 'this'.
*/
Type* checkStructSelf(Type, char[] FullName)(CrocThread* t)
{
	static assert(is(Type == struct), "checkStructSelf must be instantiated with a struct type, not with '" ~ Type.stringof ~ "'");
	checkInstParam(t, 0, FullName);
	getExtraVal(t, 0, 0);
	auto ret = &(cast(StructWrapper!(Type))cast(void*)getNativeObj(t, -1)).inst;
	pop(t);
	return ret;
}

/**
Checks that the 'this' parameter passed to a native function is an instance of the given class
type, and returns the reference to the D object instance that is referenced by 'this'.

Template Params:
	Type = The D class type that corresponds to 'this'.

	FullName = The name of the type in Croc, in dotted form.

Returns:
	A reference to the D object instance referenced by 'this'.
*/
static Type checkClassSelf(Type, char[] FullName)(CrocThread* t)
{
	static if(is(Type == interface))
	{
		checkInstParam(t, 0, FullName);
		getExtraVal(t, 0, 0);
		auto ret = cast(Type)cast(Object)cast(void*)getNativeObj(t, -1);
		pop(t);
		return ret;
	}
	else
	{
		static assert(is(Type == class), "checkClassSelf must be instantiated with a class type, not with '" ~ Type.stringof ~ "'");
		checkInstParam(t, 0, FullName);
		getExtraVal(t, 0, 0);
		auto ret = cast(Type)cast(void*)getNativeObj(t, -1);
		pop(t);
		return ret;
	}
}

/**
It's superPush!  It's better than your average push.

This is a templated push function that will take any D type that is convertible to a Croc type
and push its Croc conversion onto the stack. This includes not only simple value types, but also
arrays, associative arrays, classes, and structs. Classes and structs are convertible as long as they
have been wrapped. Arrays are convertible as long as their element type is convertible. AAs are
convertible as long as their key and value types are convertible. Arrays will become Croc arrays,
and AAs will become Croc tables. Classes and structs will become Croc instances of the wrapped
Croc class type.

Returns:
	The stack index of the newly-pushed value.
*/
word superPush(Type)(CrocThread* t, Type val)
{
	alias realType!(Type) T;

	static if(is(T == bool))
		return pushBool(t, cast(T)val);
	else static if(isIntegerType!(T))
		return pushInt(t, cast(T)val);
	else static if(isRealType!(T))
		return pushFloat(t, cast(T)val);
	else static if(isCharType!(T))
		return pushChar(t, cast(T)val);
	else static if(isStringType!(T))
	{
		static if(is(T : char[]))
			return pushString(t, cast(T)val);
		else
			return pushString(t, Utf_toString(cast(T)val));
	}
	else static if(isAAType!(T))
	{
		auto ret = newTable(t, val.length);

		foreach(k, v; val)
		{
			superPush(t, k);
			superPush(t, v);
			idxa(t, ret);
		}

		return ret;
	}
	else static if(isArrayType!(T))
	{
		auto ret = newArray(t, val.length);

		foreach(i, v; val)
		{
			superPush(t, v);
			idxai(t, ret, i);
		}

		return ret;
	}
	else static if(is(T == interface))
	{
		auto obj = cast(Object)val;

		if(obj is null)
			return pushNull(t);
		else
		{
			getWrappedClassOrSuper(t, obj.classinfo);

			if(isNull(t, -1))
				throwStdException(t, "Exception", "Cannot convert class {} to a Croc value; class type has not been wrapped", typeid(T));
			else
				return getWrappedInstance(t, obj);
		}

		assert(false);
	}
	else static if(is(T : Object))
	{
		if(val is null)
			return pushNull(t);
		else
		{
			getWrappedClassOrSuper(t, val.classinfo);

			if(isNull(t, -1))
				throwStdException(t, "Exception", "Cannot convert class {} to a Croc value; class type has not been wrapped", typeid(T));
			else
				return getWrappedInstance(t, val);
		}

		assert(false);
	}
	else static if(is(T == struct))
	{
		getWrappedClass(t, typeid(T));

		if(isNull(t, -1))
			throwStdException(t, "Exception", "Cannot convert struct {} to a Croc value; struct type has not been wrapped", typeid(T));

		newInstance(t, -1, 1);
		insertAndPop(t, -2);
		pushNativeObj(t, new StructWrapper!(Type)(val));
		setExtraVal(t, -2, 0);
		return stackSize(t) - 1;
	}
	else static if(is(T == CrocThread*))
		return pushThread(t, cast(T)val);
	else
		static assert(false, "superPush - Invalid argument type '" ~ T.stringof ~ "'");
}

/**
Like superPush, but pushes multiple values onto the stack in one function call. Calls superPush
internally, so any types that are legal to pass to superPush are legal to pass to this.

Params:
	arg1 = The first value to push. This is separated to force you to push at least one value.
	args = Any additional values to push.

Returns:
	The stack index of the first value that was pushed.
*/
word multiPush(T, U...)(CrocThread* t, T arg1, U args)
{
	auto ret = superPush(t, arg1);

	foreach(i, arg; args)
		superPush(t, args[i]);

	return ret;
}

/**
The inverse of superPush, this function allows you to get any type of value from the Croc stack
and convert it into a D type. The rules in this direction are pretty much the same as in the other:
a Croc array can only be converted into a D array as long as its elements can be converted to the
D array's element type, and similarly for Croc tables.

Strings will also be converted to the correct Unicode encoding. Keep in mind, however, that this
function will duplicate the string data onto the D heap, unlike the raw API getString function.
This is because handing off pointers to internal Croc memory to arbitrary D libraries is probably
not a good idea.
*/
Type superGet(Type)(CrocThread* t, word idx)
{
	alias realType!(Type) T;

	static if(!isStringType!(T) && isArrayType!(T))
	{
		alias typeof(T[0]) ElemType;

		if(!isArray(t, idx))
		{
			pushTypeString(t, idx);
			throwStdException(t, "Exception", "superGet - Cannot convert Croc type '{}' to D type '" ~ Type.stringof ~ "'", getString(t, -1));
		}

		auto data = getArray(t, idx).data;
		auto ret = new T(data.length);

		foreach(i, ref elem; data)
		{
			auto elemIdx = push(t, elem);

			if(!canCastTo!(ElemType)(t, elemIdx))
			{
				pushTypeString(t, idx);
				pushTypeString(t, elemIdx);
				throwStdException(t, "Exception", "superGet - Cannot convert Croc type '{}' to D type '" ~ Type.stringof ~ "': element {} should be '" ~
					ElemType.stringof ~ "', not '{}'", getString(t, -2), i, getString(t, -1));
			}

			ret[i] = superGet!(ElemType)(t, elemIdx);
			pop(t);
		}

		return cast(Type)ret;
	}
	else static if(isAAType!(T))
	{
		alias typeof(T.init.keys[0]) KeyType;
		alias typeof(T.init.values[0]) ValueType;

		if(!isTable(t, idx))
		{
			pushTypeString(t, idx);
			throwStdException(t, "Exception", "superGet - Cannot convert Croc type '{}' to D type '" ~ Type.stringof ~ "'", getString(t, -1));
		}

		T ret;

		foreach(ref key, ref val; getTable(t, idx).data)
		{
			auto keyIdx = push(t, key);

			if(!canCastTo!(KeyType)(t, keyIdx))
			{
				pushTypeString(t, idx);
				pushTypeString(t, keyIdx);
				throwStdException(t, "Exception", "superGet - Cannot convert Croc type '{}' to D type '" ~ Type.stringof ~ "': key should be '" ~
					KeyType.stringof ~ "', not '{}'", getString(t, -2), getString(t, -1));
			}

			auto valIdx = push(t, val);

			if(!canCastTo!(ValueType)(t, valIdx))
			{
				pushTypeString(t, idx);
				pushTypeString(t, valIdx);
				throwStdException(t, "Exception", "superGet - Cannot convert Croc type '{}' to D type '" ~ Type.stringof ~ "': value should be '" ~
					ValueType.stringof ~ "', not '{}'", getString(t, -2), getString(t, -1));
			}

			ret[superGet!(KeyType)(t, keyIdx)] = superGet!(ValueType)(t, valIdx);
			pop(t, 2);
		}

		return cast(Type)ret;
	}
	else static if(is(T == interface))
	{
		idx = absIndex(t, idx);

		if(isNull(t, idx))
			return null;

// 		getWrappedClass(t, typeid(T));

// 		if(!as(t, idx, -1))
		if(!isInstance(t, idx) || numExtraVals(t, idx) == 0)
			paramTypeError(t, idx, "instance of " ~ Type.stringof);

// 		pop(t);

		getExtraVal(t, idx, 0);
		auto ret = cast(Type)cast(Object)cast(void*)getNativeObj(t, -1);

		if(ret is null)
			paramTypeError(t, idx, "instance of " ~ Type.stringof);

		pop(t);

		return ret;
	}
	else static if(is(T : Object))
	{
		idx = absIndex(t, idx);

		if(isNull(t, idx))
			return null;

		getWrappedClass(t, T.classinfo);

		if(!as(t, idx, -1))
			paramTypeError(t, idx, "instance of " ~ Type.stringof);

		pop(t);

		getExtraVal(t, idx, 0);
		auto ret = cast(Type)cast(void*)getNativeObj(t, -1);
		pop(t);

		return ret;
	}
	else static if(is(T == struct))
	{
		idx = absIndex(t, idx);

		getWrappedClass(t, typeid(T));
		// the wrapped class will always be non-null, since the struct got on the stack in the first place..

		if(!as(t, idx, -1))
			paramTypeError(t, idx, "instance of " ~ Type.stringof);

		pop(t);

		getExtraVal(t, idx, 0);

		static if(!is(Type == T))
			auto ret = cast(Type)(cast(StructWrapper!(T))getNativeObj(t, -1)).inst;
		else
			auto ret = (cast(StructWrapper!(T))getNativeObj(t, -1)).inst;

		pop(t);

		return ret;
	}
	else
	{
		if(!canCastTo!(T)(t, idx))
		{
			pushTypeString(t, idx);
			throwStdException(t, "Exception", "superGet - Cannot convert Croc type '{}' to D type '" ~ Type.stringof ~ "'", getString(t, -1));
		}

		static if(is(T == bool))
		{
			return cast(Type)getBool(t, idx);
		}
		else static if(isIntegerType!(T))
		{
			return cast(Type)getInt(t, idx);
		}
		else static if(isRealType!(T))
		{
			if(isInt(t, idx))
				return cast(Type)getInt(t, idx);
			else if(isFloat(t, idx))
				return cast(Type)getFloat(t, idx);
			else
				assert(false, "superGet!(" ~ T.stringof ~ ")");
		}
		else static if(isCharType!(T))
		{
			return cast(Type)getChar(t, idx);
		}
		else static if(isStringType!(T))
		{
			static if(is(T == char[]))
				return cast(Type)getString(t, idx).dup;
			else static if(is(T == wchar[]))
				return cast(Type)Utf_toString16(getString(t, idx));
			else
				return cast(Type)Utf_toString32(getString(t, idx));
		}
		else
			static assert(false, "superGet - Invalid argument type '" ~ Type.stringof ~ "'");
	}
}

/**
Like superGet, but gets multiple consecutive values off the stack. There must be at least
as many values after the start index as you have values to get. This calls superGet internally,
so any types that are legal to get with superGet are legal here too.

Params:
	start = The stack index of the first value to retrieve.
	arg1 = The first value to get. This is separate to force you to get at least one value.
	args = Any additional values to get.
*/
void multiGet(T, U...)(CrocThread* t, word start, ref T arg1, ref U args)
{
	if(stackSize(t) - start < (U.length + 1))
		throwStdException(t, "Exception", "multiGet - Attempting to get more values ({}) than there are after the given index ({} values)", U.length + 1, stackSize(t) - start);

	arg1 = superGet!(T)(t, start);

	foreach(i, arg; args)
		args[i] = superGet!(U[i])(t, start + i + 1);
}

/**
Returns true if the value at the given stack index can be converted to the given D type,
or false otherwise. That's all.
*/
bool canCastTo(Type)(CrocThread* t, word idx)
{
	alias realType!(Type) T;

	static if(is(T == bool))
	{
		return isBool(t, idx);
	}
	else static if(isIntegerType!(T))
	{
		return isInt(t, idx);
	}
	else static if(isRealType!(T))
	{
		return isNum(t, idx);
	}
	else static if(isCharType!(T))
	{
		return isChar(t, idx);
	}
	else static if(isStringType!(T) || is(T : CrocString))
	{
		return isString(t, idx);
	}
	else static if(isAAType!(T))
	{
		if(!isTable(t, idx))
			return false;

		alias typeof(T.init.keys[0]) KeyType;
		alias typeof(T.init.values[0]) ValueType;

		foreach(ref k, ref v; mTable)
		{
			auto keyIdx = push(t, k);

			if(!canCastTo!(KeyType)(t, keyIdx))
			{
				pop(t);
				return false;
			}

			auto valIdx = push(t, v);

			if(!canCastTo!(ValueType)(t, valIdx))
			{
				pop(t, 2);
				return false;
			}

			pop(t, 2);
		}

		return true;
	}
	else static if(isArrayType!(T))
	{
		if(!isArray(t, idx))
			return false;

		alias typeof(T[0]) ElemType;

		foreach(ref v; mArray)
		{
			auto valIdx = push(t, v);

			if(!canCastTo!(ElemType)(t, valIdx))
			{
				pop(t);
				return false;
			}

			pop(t);
		}

		return true;
	}
	else static if(is(T : Object))
	{
		if(isNull(t, idx))
			return true;

		getWrappedClass(t, T.classinfo);
		auto ret = as(t, idx, -1);
		pop(t);
		return ret;
	}
	else static if(is(T == struct))
	{
		getWrappedClass(t, typeid(T));
		auto ret = as(t, idx, -1);
		pop(t);
		return ret;
	}
	else
		return false;
}

/**

*/
bool TypesMatch(T...)(CrocThread* t)
{
	foreach(i, type; T)
	{
		if(!canCastTo!(type)(t, i + 1))
			return false;
		else
		{
			static if(isRealType!(type))
			{
				if(isInt(t, i + 1))
					return false;
			}
		}
	}

	return true;
}

// ================================================================================================================================================
// Private
// ================================================================================================================================================

private:

template PropAnalysis(alias func, funcType)
{
	alias ParameterTupleOf!(funcType) Args;

	static if(Args.length == 0)
	{
		alias realType!(ReturnTypeOf!(funcType)) propType;

		static assert(!is(propType == void), "property getter '" ~ NameOfFunc!(func) ~ "' may not return void");

		static if(is(typeof(func(InitOf!(propType))) T))
			const bool readOnly = false;
		else
			const bool readOnly = true;
	}
	else
	{
		const bool readOnly = false;
		alias Args[0] propType;
	}
}

template ReadOnly(alias func, funcType)
{
	const bool ReadOnly = PropAnalysis!(func, funcType).readOnly;
}

template PropType(alias func, funcType)
{
	alias PropAnalysis!(func, funcType).propType PropType;
}

void commonNamespace(char[] name, bool isModule, Members...)(CrocThread* t)
{
	static if(!isModule)
		newNamespace(t, name);

	foreach(i, member; Members)
	{
		static if(is(typeof(member.isFunc)))
			newFunction(t, &member.WrappedFunc, member.Name);
		else static if(is(typeof(member.isNamespace)))
			commonNamespace!(member.Name, false, member.Values)(t);
		else static if(is(typeof(member.isValue)))
			superPush(t, member.Value);
		else static if(is(typeof(member.isType)))
			member.init!(name)(t);
		else static if(isModule)
			static assert(false, "Invalid member type '" ~ member.stringof ~ "' in wrapped module '" ~ name ~ "'");
		else
			static assert(false, "Invalid member type '" ~ member.stringof ~ "' in wrapped namespace '" ~ name ~ "'");

		static if(isModule)
			newGlobal(t, member.Name);
		else
			fielda(t, -2, member.Name);
	}
}

void checkInitialized(CrocThread* t)
{
	getRegistry(t);
	pushString(t, "croc.bind.initialized");

	if(!opin(t, -1, -2))
	{
		newTable(t);       fielda(t, -3, "croc.bind.WrappedClasses");
		newTable(t);       fielda(t, -3, "croc.bind.WrappedInstances");
		pushBool(t, true); fielda(t, -3);
		pop(t);
	}
	else
		pop(t, 2);
}

word pushStructClass(Type, char[] ModName, char[] StructName)(CrocThread* t)
{
	return newClass(t, StructName);
}

class WrappedClass(Type, char[] _classname_, char[] moduleName, Members...) : Type
{
	protected CrocVM* _vm_;

	const char[] typeName = NameOfType!(Type);
	alias GetCtors!(Members) Ctors;
	static assert(Ctors.length <= 1, "Cannot have more than one WrapCtors for type " ~ typeName);

	static if(moduleName.length == 0)
		const TypeName = _classname_;
	else
		const TypeName = moduleName ~ "." ~ _classname_;

	CrocThread* _haveCrocOverload_(char[] methodName)
	{
		auto t = currentThread(_vm_);

		getRegistryVar(t, "croc.bind.WrappedInstances");
		pushNativeObj(t, this);
		idx(t, -2);
		deref(t, -1);

		if(isNull(t, -1))
		{
			pop(t, 3);
			return null;
		}
		else
		{
			superOf(t, -1);
			field(t, -1, methodName);

			if(funcIsNative(t, -1))
			{
				pop(t, 5);
				return null;
			}
			else
			{
				pop(t, 2);
				insertAndPop(t, -3);
				return t;
			}
		}
	}

	static if(Ctors.length == 1)
	{
		// alias Ctors[0].Types blah; doesn't parse right
		alias Ctors[0] DUMMY;

		static if(is(typeof(new Type())))
			alias Unique!(Tuple!(void function(), DUMMY.Types)) CleanCtors;
		else
			alias DUMMY.Types CleanCtors;

		mixin(ClassCtorShims!(CleanCtors));

		private static uword constructor(CrocThread* t)
		{
			auto numParams = stackSize(t) - 1;
			checkInstParam(t, 0, TypeName);

			static if(is(typeof(new Type())))
				const minArgs = 0;
			else
				const minArgs = ParameterTupleOf!(CleanCtors[0]).length;

			const maxArgs = ParameterTupleOf!(CleanCtors[$ - 1]).length;

			if(numParams < minArgs)
				throwStdException(t, "Exception", "At least " ~ minArgs.stringof ~ " parameter" ~ (minArgs == 1 ? "" : "s") ~ " expected, not {}", numParams);

			if(numParams > maxArgs)
				numParams = maxArgs;

			static if(minArgs == 0)
			{
				if(numParams == 0)
				{
					auto obj = new typeof(this)(getVM(t));
					pushNativeObj(t, obj);
					setExtraVal(t, 0, 0);
					setWrappedInstance(t, obj, 0);
					return 0;
				}
			}

			const Switch = ClassCtorCases!(CleanCtors);
			mixin(Switch);

			auto buf = StrBuffer(t);

			buf.addChar('(');

			if(numParams > 0)
			{
				pushTypeString(t, 1);
				buf.addTop();

				for(uword i = 2; i <= numParams; i++)
				{
					buf.addString(", ");
					pushTypeString(t, i);
					buf.addTop();
				}
			}

			buf.addChar(')');
			buf.finish();
			throwStdException(t, "Exception", "Parameter list {} passed to constructor does not match any wrapped constructors", getString(t, -1));
		}
	}
	else
	{
		static assert(is(typeof(new Type())), "Cannot call default constructor for class " ~ typeName ~ "; please wrap a constructor explicitly");

		private this(CrocVM* vm)
		{
			_vm_ = vm;

			// BUG: is, uh, _ctor supposed to be usable?
			static if(is(typeof(&Type._ctor)))
				super();
		}

		private static uword constructor(CrocThread* t)
		{
			checkInstParam(t, 0, TypeName);
			auto obj = new typeof(this)(getVM(t));
			pushNativeObj(t, obj);
			setExtraVal(t, 0, 0);
			setWrappedInstance(t, obj, 0);
			return 0;
		}
	}

	mixin ClassOverrideMethods!(Type, TypeName, GetMethods!(Members));
	mixin ClassCrocMethods!(Type, TypeName, GetMethods!(Members));
	mixin ClassProperties!(Type, GetProperties!(Members));

	private static word init(CrocThread* t)
	{
		alias BaseTypeTupleOf!(Type)[0] BaseClass;

		static if(!is(BaseClass == Object))
			auto base = getWrappedClass(t, BaseClass.classinfo);
		else
			auto base = pushNull(t);

		newClass(t, base, _classname_);

		foreach(i, member; Members)
		{
			static if(is(typeof(member.isMethod)))
			{
				auto f = mixin("&croc_" ~ member.Name);
				newFunction(t, f, _classname_ ~ "." ~ member.Name);
				fielda(t, -2, member.Name);
			}
			else static if(is(typeof(member.isProperty)))
			{
				auto f = mixin("&_prop_" ~ member.Name);
				newFunction(t, f, _classname_ ~ "._prop_" ~ member.Name);
				fielda(t, -2, "_prop_" ~ member.Name);
			}
			else static if(is(typeof(member.isCtors)))
			{
				// ignore
			}
			else static if(is(typeof(member.isValue)))
			{
				superPush(t, member.Value);
				fielda(t, -2, member.Name);
			}
			else
				static assert(false, "Invalid member type '" ~ member.stringof ~ "' in wrapped type '" ~ typeName ~ "'");
		}

		static if(haveProperties)
		{
			newFunction(t, &opField, _classname_ ~ ".opField");             fielda(t, -2, "opField");
			newFunction(t, &opFieldAssign, _classname_ ~ ".opFieldAssign"); fielda(t, -2, "opFieldAssign");
		}

		newFunction(t, &constructor, _classname_ ~ ".constructor");
		fielda(t, -2, "constructor");

		insertAndPop(t, -2);
		return stackSize(t) - 1;
	}
}

class StructWrapper(Type)
{
	Type inst;
	
	this(Type t)
	{
		inst = t;
	}
}

struct WrappedStruct(Type, char[] name, char[] moduleName, Members...)
{
static:
	const char[] typeName = NameOfType!(Type);
	alias GetCtors!(Members) Ctors;
	static assert(Ctors.length <= 1, "Cannot have more than one WrapCtors for type " ~ typeName);

	static if(moduleName.length == 0)
		const TypeName = name;
	else
		const TypeName = moduleName ~ "." ~ name;

	static if(Ctors.length == 1)
	{
		// alias Ctors[0].Types blah; doesn't parse right
		alias Ctors[0] DUMMY;
		alias DUMMY.Types CleanCtors;

		private static uword constructor(CrocThread* t)
		{
			auto numParams = stackSize(t) - 1;
			checkInstParam(t, 0, TypeName);

			static if(is(typeof(Type())))
				const minArgs = 0;
			else
				const minArgs = ParameterTupleOf!(CleanCtors[0]).length;

			const maxArgs = ParameterTupleOf!(CleanCtors[$ - 1]).length;

			if(numParams < minArgs)
				throwStdException(t, "Exception", "At least " ~ minArgs.stringof ~ " parameter" ~ (minArgs == 1 ? "" : "s") ~ " expected, not {}", numParams);

			if(numParams > maxArgs)
				numParams = maxArgs;

			static if(minArgs == 0)
			{
				if(numParams == 0)
				{
					pushNativeObj(t, new StructWrapper!(Type)(Type()));
					setExtraVal(t, 0, 0);
					return 0;
				}
			}

			const Switch = StructCtorCases!(CleanCtors);
			mixin(Switch);

			auto buf = StrBuffer(t);

			buf.addChar('(');

			if(numParams > 0)
			{
				pushTypeString(t, 1);
				buf.addTop();

				for(uword i = 2; i <= numParams; i++)
				{
					buf.addString(", ");
					pushTypeString(t, i);
					buf.addTop();
				}
			}

			buf.addChar(')');
			buf.finish();
			throwStdException(t, "Exception", "Parameter list {} passed to constructor does not match any wrapped constructors", getString(t, -1));
		}
	}
	else
	{
		static assert(is(typeof(Type())), "Cannot call default constructor for struct " ~ typeName ~ "; please wrap a constructor explicitly");

		private static uword constructor(CrocThread* t)
		{
			checkInstParam(t, 0, TypeName);
			pushNativeObj(t, new StructWrapper!(Type)(Type()));
			setExtraVal(t, 0, 0);
			return 0;
		}
	}

	mixin StructProperties!(Type, StructFieldsToProps!(Type), GetProperties!(Members));

	private static word init(CrocThread* t)
	{
		pushStructClass!(Type, moduleName, name)(t);

		foreach(i, member; Tuple!(StructFieldsToProps!(Type), Members))
		{
			static if(is(typeof(member.isMethod)))
			{
				auto f = &WrappedStructMethod!(member.Func, member.FuncType, Type, TypeName, member.explicitType);
				newFunction(t, f, name ~ "." ~ member.Name);
				fielda(t, -2, member.Name);
			}
			else static if(is(typeof(member.isProperty)))
			{
				auto f = mixin("&_prop_" ~ member.Name);
				newFunction(t, f, name ~ "._prop_" ~ member.Name);
				fielda(t, -2, "_prop_" ~ member.Name);
			}
			else static if(is(typeof(member.isCtors)))
			{
				// ignore
			}
			else static if(is(typeof(member.isValue)))
			{
				superPush(t, member.Value);
				fielda(t, -2, member.Name);
			}
			else
				static assert(false, "Invalid member type '" ~ member.stringof ~ "' in wrapped type '" ~ typeName ~ "'");
		}

		static if(haveProperties)
		{
			newFunction(t, &opField, name ~ ".opField");             fielda(t, -2, "opField");
			newFunction(t, &opFieldAssign, name ~ ".opFieldAssign"); fielda(t, -2, "opFieldAssign");
		}

		newFunction(t, &constructor, name ~ ".constructor");
		fielda(t, -2, "constructor");

		return stackSize(t) - 1;
	}
}

template ClassCtorShims(Ctors...)
{
	const ClassCtorShims = ClassCtorShimsImpl!(0, Ctors);
}

template ClassCtorShimsImpl(uint idx, Ctors...)
{
	static if(idx >= Ctors.length)
		const ClassCtorShimsImpl = "";
	else
	{
		static if(ParameterTupleOf!(Ctors[idx]).length == 0)
		{
			const ClassCtorShimsImpl =
			"this(CrocVM* vm)\n"
			"{\n"
			"	_vm_ = vm;\n"
			"	super();\n"
			"}\n" ~ ClassCtorShimsImpl!(idx + 1, Ctors);
		}
		else
		{
			const ClassCtorShimsImpl =
			"this(CrocVM* vm, ParameterTupleOf!(CleanCtors[" ~ idx.stringof ~ "]) args)\n"
			"{\n"
			"	_vm_ = vm;\n"
			"	super(args);\n"
			"}\n" ~ ClassCtorShimsImpl!(idx + 1, Ctors);
		}
	}
}

// When you wrap a method, three things happen. The first is that an overriding D method is created
// in the shim class which detects whether or not a Croc overload exists, and dispatches appropriately.
// Continued below..
template ClassOverrideMethods(Type, char[] TypeName) {}
template ClassOverrideMethods(Type, char[] TypeName, alias X, T...)
{
	mixin("ReturnTypeOf!(X.FuncType) " ~ X.Name ~ "(ParameterTupleOf!(X.Func) args)\n"
	"{\n" ~
	"	if(auto t = _haveCrocOverload_(`" ~ X.Name ~ "`))\n"
	"	{\n"
	"		// instance is on top\n"
	"		auto reg = stackSize(t) - 1;\n"
	"		pushNull(t);\n"
	"		foreach(arg; args) superPush(t, arg);\n" ~
	(is(ReturnTypeOf!(X.FuncType) == void)
	?
	"		methodCall(t, reg, `" ~ X.Name ~ "`, 0); return;\n"
	:
	"		methodCall(t, reg, `" ~ X.Name ~ "`, 1);\n"
	"		auto ret = superGet!(ReturnTypeOf!(X.FuncType))(t, -1);\n"
	"		pop(t); return ret;\n") ~
	"	}\n"
	"	else\n"
	"		return super." ~ NameOfFunc!(X.Func) ~ "(args);\n"
	"}\n");

	 mixin ClassOverrideMethods!(Type, TypeName, T);
}

// ..the other two things that happen is that two methods - one static and one dynamic - are created.
// The static one is the one that is actually exposed to Croc and all it does is check that the 'this'
// parameter is correct and calls the dynamic one. The dynamic one gets the params off the stack and
// calls the real D method.
template ClassCrocMethods(Type, char[] TypeName) {}
template ClassCrocMethods(Type, char[] TypeName, alias X, T...)
{
	mixin("mixin .WrappedMethod!(X.Func, X.FuncType, Type, TypeName, X.explicitType) wrapped_" ~ X.Name ~ ";");

	mixin(
	"static uword croc_" ~ X.Name ~ "(CrocThread* t)\n"
	"{\n" ~
	(X.explicitType
	? "	const minArgs = NumParams!(X.FuncType);\n"
	: "	const minArgs = MinArgs!(X.Func);\n") ~
	"	const maxArgs = NumParams!(X.FuncType);\n"
	"	auto numParams = stackSize(t) - 1;\n"
	"	if(numParams < minArgs)\n"
	"		throwStdException(t, `Exception`, `At least ` ~ minArgs.stringof ~ ` parameter` ~ (minArgs == 1 ? `` : `s`) ~ ` expected, not {}`, numParams);\n"

	"	if(numParams > maxArgs)\n"
	"		numParams = maxArgs;\n"

	"	auto self = checkClassSelf!(Type, TypeName)(t);\n"
	
	"	assert(self !is null, `Invalid 'this' parameter passed to method ` ~ Type.stringof ~ `.` ~ X.Name);\n"

	"	if(auto wrappedSelf = cast(typeof(this))self)\n"
	"		return wrappedSelf.wrapped_" ~ X.Name ~ ".WrappedMethod(t);\n"
	"	else\n"
	"		return WrappedNativeMethod!(X.Func, X.FuncType, X.explicitType)(t, numParams, self);\n"
	"}\n");

	mixin ClassCrocMethods!(Type, TypeName, T);
}

// For each property that the class defines, two things happen - one, a method
// called _prop_name is created that does the actual getting and setting. Two,
// an entry is created in the opField and opFieldAssign methods that will call
// that method when the given field is accessed.
// If the class defines no properties, no opField[Assign] methods are generated.

template ClassProperties(Type)
{
	const haveProperties = false;
}

template ClassProperties(Type, X, T...)
{
	const haveProperties = true;
	mixin ClassPropertiesImpl!(Type, X, T);
	mixin PropertiesImpl!(Type, X, T);
}

// generates opField and opFieldAssign methods.
template ClassPropertiesImpl(Type, T...)
{
	mixin(
	"static uword opField(CrocThread* t)\n"
	"{\n"
	"	auto self = checkClassSelf!(Type, TypeName)(t);\n"
	"	auto fieldName = checkStringParam(t, 1);\n" ~
		GetField!(Type, T) ~
	"	return 1;\n"
	"}\n"

	"static uword opFieldAssign(CrocThread* t)\n"
	"{\n"
	"	auto self = checkClassSelf!(Type, TypeName)(t);\n"
	"	auto fieldName = checkStringParam(t, 1);\n" ~
		SetField!(Type, T) ~
	"	return 0;\n"
	"}\n");
}

template StructProperties(Type)
{
	const haveProperties = false;
}

template StructProperties(Type, X, T...)
{
	const haveProperties = true;
	mixin StructPropertiesImpl!(Type, X, T);
	mixin PropertiesImpl!(Type, X, T);
}

template StructPropertiesImpl(Type, T...)
{
	mixin(
	"static uword opField(CrocThread* t)\n"
	"{\n"
	"	auto self = checkStructSelf!(Type, TypeName)(t);\n"
	"	auto fieldName = checkStringParam(t, 1);\n" ~
		GetField!(Type, T) ~
	"	return 1;\n"
	"}\n"

	"static uword opFieldAssign(CrocThread* t)\n"
	"{\n"
	"	auto self = checkStructSelf!(Type, TypeName)(t);\n"
	"	auto fieldName = checkStringParam(t, 1);\n" ~
		SetField!(Type, T) ~
	"	return 0;\n"
	"}\n");
}

// Common to both classes and structs, generates the _prop_name methods.
template PropertiesImpl(Type) {}
template PropertiesImpl(Type, X, T...)
{
	mixin(
	"static uword _prop_" ~ X.Name ~ "(CrocThread* t)\n"
	"{\n"
	"	auto numParams = stackSize(t) - 1;\n"
	"	auto self = check" ~ (is(Type == class) ? "Class" : "Struct") ~ "Self!(Type, TypeName)(t);\n"
	"	return PropImpl!(`" ~ X.DName ~ "`, X.readOnly, X.propType, TypeName)(t, numParams, self);\n"
	"}\n");

	mixin PropertiesImpl!(Type, T);
}

template GetField(Type, T...)
{
	const GetField =
	"switch(fieldName)\n"
	"{\n"
	"	default:\n"
	"		throwStdException(t, `Exception`, `Attempting to access nonexistent field '{}' from type " ~ Type.stringof ~ "`, fieldName);\n" ~
		GetFieldImpl!(T) ~
	"}\n";
}

template GetFieldImpl(Fields...)
{
	static if(Fields.length == 0)
		const GetFieldImpl = "";
	else
	{
		const GetFieldImpl =
		"case `" ~ Fields[0].Name ~ "`:\n"
		"	static if(!is(typeof(self." ~ Fields[0].DName ~ ")))\n"
		"		goto default;\n"
		"	else\n"
		"	{\n"
		"		dup(t, 0);\n"
		"		pushNull(t);\n"
		"		methodCall(t, -2, `_prop_" ~ Fields[0].Name ~ "`, 1);\n"
		"		break;\n"
		"	}\n" ~
		GetFieldImpl!(Fields[1 .. $]);
	}
}

template SetField(Type, T...)
{
	const SetField =
	"switch(fieldName)\n"
	"{\n"
	"	default:\n"
	"		throwStdException(t, `Exception`, `Attempting to access nonexistent field '{}' from type " ~ Type.stringof ~ "`, fieldName);\n" ~
		SetFieldImpl!(T) ~
	"}\n";
}

template SetFieldImpl(Fields...)
{
	static if(Fields.length == 0)
		const SetFieldImpl = "";
	else
	{
		const SetFieldImpl =
		"case `" ~ Fields[0].Name ~ "`:\n"
		"	static if(!is(typeof(self." ~ Fields[0].DName ~ ")))\n"
		"		goto default;\n"
		"	else\n"
		"	{\n"
		"		dup(t, 0);\n"
		"		pushNull(t);\n"
		"		dup(t, 2);\n"
		"		methodCall(t, -3, `_prop_" ~ Fields[0].Name ~ "`, 0);\n"
		"		break;\n"
		"	}\n" ~
		SetFieldImpl!(Fields[1 .. $]);
	}
}

template WrappedFunc(alias func, char[] name, funcType, bool explicitType)
{
	static uword WrappedFunc(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		
		static if(explicitType)
			const minArgs = NumParams!(funcType);
		else
			const minArgs = MinArgs!(func);

		const maxArgs = NumParams!(funcType);

		if(numParams < minArgs)
			throwStdException(t, "Exception", "At least" ~ minArgs.stringof ~ " parameter" ~ (minArgs == 1 ? "" : "s") ~ " expected, not {}", numParams);

		if(numParams > maxArgs)
			numParams = maxArgs;

		static if(NumParams!(funcType) == 0)
		{
			static if(is(ReturnTypeOf!(funcType) == void))
			{
				safeCode(t, func());
				return 0;
			}
			else
			{
				superPush(t, safeCode(t, func()));
				return 1;
			}
		}
		else
		{
			ParameterTupleOf!(funcType) args;

			static if(minArgs == 0)
			{
				if(numParams == 0)
				{
					static if(is(ReturnTypeOf!(funcType) == void))
					{
						safeCode(t, func());
						return 0;
					}
					else
					{
						superPush(t, safeCode(t, func()));
						return 1;
					}
				}
			}

			foreach(i, arg; args)
			{
				const argNum = i + 1;

				if(i < numParams)
					args[i] = superGet!(typeof(args[i]))(t, argNum);

				static if(argNum >= minArgs && argNum <= maxArgs)
				{
					if(argNum == numParams)
					{
						static if(is(ReturnTypeOf!(funcType) == void))
						{
							safeCode(t, func(args[0 .. argNum]));
							return 0;
						}
						else
						{
							superPush(t, safeCode(t, func(args[0 .. argNum])));
							return 1;
						}
					}
				}
			}

			assert(false, "WrappedFunc (" ~ name ~ ") should never ever get here.");
		}
	}
}

template WrappedNativeMethod(alias func, funcType, bool explicitType)
{
	private uword WrappedNativeMethod(Type)(CrocThread* t, uword numParams, Type self)
	{
		static if(explicitType)
			const minArgs = NumParams!(funcType);
		else
			const minArgs = MinArgs!(func);

		const maxArgs = NumParams!(funcType);
		const name = NameOfFunc!(func);

		static if(NumParams!(funcType) == 0)
		{
			static if(is(ReturnTypeOf!(funcType) == void))
			{
				safeCode(t, mixin("self." ~ name ~ "()"));
				return 0;
			}
			else
			{
				superPush(t, safeCode(t, mixin("self." ~ name ~ "()")));
				return 1;
			}
		}
		else
		{
			ParameterTupleOf!(funcType) args;

			static if(minArgs == 0)
			{
				if(numParams == 0)
				{
					static if(is(ReturnTypeOf!(funcType) == void))
					{
						safeCode(t, mixin("self." ~  name ~ "()"));
						return 0;
					}
					else
					{
						superPush(t, safeCode(t, mixin("self." ~ name ~ "()")));
						return 1;
					}
				}
			}
	
			foreach(i, arg; args)
			{
				const argNum = i + 1;
	
				if(i < numParams)
					args[i] = superGet!(typeof(args[i]))(t, argNum);
	
				static if(argNum >= minArgs && argNum <= maxArgs)
				{
					if(argNum == numParams)
					{
						static if(is(ReturnTypeOf!(funcType) == void))
						{
							safeCode(t, mixin("self." ~ name ~ "(args[0 .. argNum])"));
							return 0;
						}
						else
						{
							superPush(t, safeCode(t, mixin("self." ~ name ~ "(args[0 .. argNum])")));
							return 1;
						}
					}
				}
			}
		}
	
		assert(false, "WrappedNativeMethod (" ~ name ~ ") should never ever get here.");
	}
}

template WrappedMethod(alias func, funcType, Type, char[] FullName, bool explicitType)
{
	private uword WrappedMethod(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		static if(explicitType)
			const minArgs = NumParams!(funcType);
		else
			const minArgs = MinArgs!(func);

		const maxArgs = NumParams!(funcType);
		const name = NameOfFunc!(func);

		static if(NumParams!(funcType) == 0)
		{
			static if(is(ReturnTypeOf!(funcType) == void))
			{
				safeCode(t, mixin("super." ~ name ~ "()"));
				return 0;
			}
			else
			{
				superPush(t, safeCode(t, mixin("super." ~ name ~ "()")));
				return 1;
			}
		}
		else
		{
			ParameterTupleOf!(funcType) args;

			static if(minArgs == 0)
			{
				if(numParams == 0)
				{
					static if(is(ReturnTypeOf!(funcType) == void))
					{
						safeCode(t, mixin("super." ~  name ~ "()"));
						return 0;
					}
					else
					{
						superPush(t, safeCode(t, mixin("super." ~ name ~ "()")));
						return 1;
					}
				}
			}
			
			foreach(i, arg; args)
			{
				const argNum = i + 1;

				if(i < numParams)
					args[i] = superGet!(typeof(args[i]))(t, argNum);

				static if(argNum >= minArgs && argNum <= maxArgs)
				{
					if(argNum == numParams)
					{
						static if(is(ReturnTypeOf!(funcType) == void))
						{
							safeCode(t, mixin("super." ~ name ~ "(args[0 .. argNum])"));
							return 0;
						}
						else
						{
							superPush(t, safeCode(t, mixin("super." ~ name ~ "(args[0 .. argNum])")));
							return 1;
						}
					}
				}
			}
		}

		assert(false, "WrappedMethod (" ~ name ~ ") should never ever get here.");
	}
}

uword WrappedStructMethod(alias func, funcType, Type, char[] FullName, bool explicitType)(CrocThread* t)
{
	auto numParams = stackSize(t) - 1;
	static if(explicitType)
		const minArgs = NumParams!(funcType);
	else
		const minArgs = MinArgs!(func);

	const maxArgs = NumParams!(funcType);
	const name = NameOfFunc!(func);

	auto self = checkStructSelf!(Type, FullName)(t);
	assert(self !is null, "Invalid 'this' parameter passed to method " ~ Type.stringof ~ "." ~ name);

	static if(NumParams!(funcType) == 0)
	{
		static if(is(ReturnTypeOf!(funcType) == void))
		{
			safeCode(t, mixin("self." ~ name ~ "()"));
			return 0;
		}
		else
		{
			superPush(t, safeCode(t, mixin("self." ~ name ~ "()")));
			return 1;
		}
	}
	else
	{
		ParameterTupleOf!(funcType) args;

		static if(minArgs == 0)
		{
			if(numParams == 0)
			{
				static if(is(ReturnTypeOf!(funcType) == void))
				{
					safeCode(t, mixin("self." ~  name ~ "()"));
					return 0;
				}
				else
				{
					superPush(t, safeCode(t, mixin("self." ~ name ~ "()")));
					return 1;
				}
			}
		}

		foreach(i, arg; args)
		{
			const argNum = i + 1;

			if(i < numParams)
				args[i] = superGet!(typeof(args[i]))(t, argNum);

			static if(argNum >= minArgs && argNum <= maxArgs)
			{
				if(argNum == numParams)
				{
					static if(is(ReturnTypeOf!(funcType) == void))
					{
						safeCode(t, mixin("self." ~ name ~ "(args[0 .. argNum])"));
						return 0;
					}
					else
					{
						superPush(t, safeCode(t, mixin("self." ~ name ~ "(args[0 .. argNum])")));
						return 1;
					}
				}
			}
		}
	}

	assert(false, "WrappedStructMethod (" ~ name ~ ") should never ever get here.");
}

template PropImpl(char[] name, bool readOnly, propType, char[] FullName)
{
	uword PropImpl(Type)(CrocThread* t, uword numParams, Type self)
	{
		static if(readOnly)
		{
			if(numParams == 0)
			{
				superPush(t, safeCode(t, mixin("self." ~ name)));
				return 1;
			}
			else
			{
				throwStdException(t, "Exception", "Attempting to set read-only property '" ~ name ~ "' of type '" ~ FullName ~ "'");
				assert(false, "PropImpl should never ever get here.");
			}
		}
		else
		{
			// GODDOMMOT FRONK
			// I can't check anything in here because FUCKING DCrocFE will EAT THE GODDAMNED ERROR
			// and cause RANDOM ERRORS ON VALID CODE in WrappedClass. WONDERFUL.
// 			static assert(is(typeof({mixin("self." ~ name ~ " = self." ~ name ~ ";");})),
// 				"property '" ~ NameOfFunc!(func) ~ "' has no setter");

			if(numParams == 0)
			{
				superPush(t, safeCode(t, mixin("self." ~ name)));
				return 1;
			}
			else
			{
				safeCode(t, mixin("self." ~ name ~ " = superGet!(propType)(t, 1)"));
				return 0;
			}
		}
	}
}

template ClassCtorCases(Ctors...)
{
	const ClassCtorCases = "switch(numParams) { default: throwStdException(t, \"Exception\", \"Invalid number of parameters ({})\", numParams);\n"
		~ ClassCtorCasesImpl!(-1, 0, Ctors) ~ "\nbreak; }";
}

template ClassCtorCasesImpl(int num, int idx, Ctors...)
{
	static if(Ctors.length == 0)
		const ClassCtorCasesImpl = "";
	else static if(NumParams!(Ctors[0]) != num)
		const ClassCtorCasesImpl = "break;\ncase " ~ NumParams!(Ctors[0]).stringof ~ ":\n" ~ ClassCtorCasesImpl!(NumParams!(Ctors[0]), idx, Ctors);
	else
	{
		const ClassCtorCasesImpl = "if(TypesMatch!(ParameterTupleOf!(CleanCtors[" ~ idx.stringof ~ "]))(t))
{
	ParameterTupleOf!(CleanCtors[" ~ idx.stringof ~ "]) params;

	foreach(i, arg; params)
		params[i] = superGet!(typeof(arg))(t, i + 1);

	auto obj = new typeof(this)(getVM(t), params);
	pushNativeObj(t, obj);
	setExtraVal(t, 0, 0);
	setWrappedInstance(t, obj, 0);
	return 0;
}\n\n" ~ ClassCtorCasesImpl!(num, idx + 1, Ctors[1 .. $]);
	}
}

template StructCtorCases(Ctors...)
{
	const StructCtorCases = "switch(numParams) { default: throwStdException(t, \"Exception\", \"Invalid number of parameters ({})\", numParams);\n"
		~ StructCtorCasesImpl!(-1, 0, Ctors) ~ "\nbreak; }";
}

template StructCtorCasesImpl(int num, int idx, Ctors...)
{
	static if(Ctors.length == 0)
		const StructCtorCasesImpl = "";
	else static if(NumParams!(Ctors[0]) != num)
		const StructCtorCasesImpl = "break;\ncase " ~ NumParams!(Ctors[0]).stringof ~ ":\n" ~ StructCtorCasesImpl!(NumParams!(Ctors[0]), idx, Ctors);
	else
	{
		const StructCtorCasesImpl = "if(TypesMatch!(ParameterTupleOf!(CleanCtors[" ~ idx.stringof ~ "]))(t))
{
	ParameterTupleOf!(CleanCtors[" ~ idx.stringof ~ "]) params;

	foreach(i, arg; params)
		params[i] = superGet!(typeof(arg))(t, i + 1);

	pushNativeObj(t, new StructWrapper!(Type)(Type(params)));
	setExtraVal(t, 0, 0);
	//self.updateFields();
	return 0;
}\n\n" ~ StructCtorCasesImpl!(num, idx + 1, Ctors[1 .. $]);
	}
}

template NumParams(T)
{
	const NumParams = ParameterTupleOf!(T).length;
}

template SortByNumParams(T1, T2)
{
	const SortByNumParams = cast(int)NumParams!(T1) - cast(int)NumParams!(T2);
}

template GetCtors(T...)
{
	static if(T.length == 0)
		alias Tuple!() GetCtors;
	else static if(is(typeof(T[0].isCtors)))
		alias Tuple!(T[0], GetCtors!(T[1 .. $])) GetCtors;
	else
		alias GetCtors!(T[1 .. $]) GetCtors;
}

template GetMethods(T...)
{
	static if(T.length == 0)
		alias Tuple!() GetMethods;
	else static if(is(typeof(T[0].isMethod)))
		alias Tuple!(T[0], GetMethods!(T[1 .. $])) GetMethods;
	else
		alias GetMethods!(T[1 .. $]) GetMethods;
}

template GetProperties(T...)
{
	static if(T.length == 0)
		alias Tuple!() GetProperties;
	else static if(is(typeof(T[0].isProperty)))
		alias Tuple!(T[0], GetProperties!(T[1 .. $])) GetProperties;
	else
		alias GetProperties!(T[1 .. $]) GetProperties;
}

struct StructFieldProp(char[] name, type, size_t idx)
{
	const bool isProperty = true;
	const char[] Name = name;
	const char[] DName = "tupleof[" ~ idx.stringof ~ "]";
	const bool readOnly = false;
	alias type propType;
}

template IsAccessibleProp(T, uint idx)
{
	const IsAccessibleProp = is(typeof({ CrocThread* t; typeof(T.tupleof[idx]) x; superPush(t, x); }));
}

template StructFieldsToProps(T, uint idx = 0)
{
	static if(idx >= T.tupleof.length)
		alias Tuple!() StructFieldsToProps;
	else static if(IsAccessibleProp!(T, idx))
		alias Tuple!(StructFieldProp!(GetLastName!(T.tupleof[idx].stringof), typeof(T.tupleof[idx]), idx), StructFieldsToProps!(T, idx + 1)) StructFieldsToProps;
	else
		alias StructFieldsToProps!(T, idx + 1) StructFieldsToProps;
}