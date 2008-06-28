/******************************************************************************
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

module minid.baselib;

import minid.ex;
import minid.interpreter;
import minid.misc;
import minid.obj;
import minid.string;
import minid.types;
import minid.vm;

import Integer = tango.text.convert.Integer;
import tango.io.Console;
import tango.io.GrowBuffer;
import tango.io.Print;
import tango.io.Stdout;
import tango.stdc.ctype;
import utf = tango.text.convert.Utf;

private void register(MDThread* t, dchar[] name, NativeFunc func, size_t numUpvals = 0)
{
	newFunction(t, func, name, numUpvals);
	newGlobal(t, name);
}

struct BaseLib
{
static:
	public void init(MDThread* t)
	{
		// Object
		auto s = pushObject(t, obj.create(t.vm.alloc, string.create(t.vm, "Object"), null));
		newFunction(t, &objectClone, "Object.clone");
		fielda(t, s, "clone");
		newGlobal(t, "Object");

// 		// StringBuffer
// 		globals["StringBuffer"d] =    new MDStringBufferClass(_Object);
// 
		// Really basic stuff
// 		globals["getTraceback"d] =    new MDClosure(globals.ns, &getTraceback,          "getTraceback");
// 		globals["haltThread"d] =      new MDClosure(globals.ns, &haltThread,            "haltThread");
		register(t, "currentThread", &currentThread);
// 		globals["setModuleLoader"d] = new MDClosure(globals.ns, &setModuleLoader,       "setModuleLoader");
// 		globals["reloadModule"d] =    new MDClosure(globals.ns, &reloadModule,          "reloadModule");
// 		globals["removeKey"d] =       new MDClosure(globals.ns, &removeKey,             "removeKey");
		register(t, "rawSet", &rawSet);
		register(t, "rawGet", &rawGet);
		register(t, "runMain", &runMain);

// 		// Functional stuff
		register(t, "curry", &curry);
		register(t, "bindContext", &bindContext);
// 
// 		// Reflection-esque stuff
// 		globals["findGlobal"d] =      new MDClosure(globals.ns, &findGlobal,            "findGlobal");
// 		globals["isSet"d] =           new MDClosure(globals.ns, &isSet,                 "isSet");
// 		globals["typeof"d] =          new MDClosure(globals.ns, &mdtypeof,              "typeof");
// 		globals["fieldsOf"d] =        new MDClosure(globals.ns, &fieldsOf,              "fieldsOf");
// 		globals["allFieldsOf"d] =     new MDClosure(globals.ns, &allFieldsOf,           "allFieldsOf");
// 		globals["hasField"d] =        new MDClosure(globals.ns, &hasField,              "hasField");
// 		globals["hasMethod"d] =       new MDClosure(globals.ns, &hasMethod,             "hasMethod");
// 		globals["hasAttributes"d] =   new MDClosure(globals.ns, &hasAttributes,         "hasAttributes");
// 		globals["attributesOf"d] =    new MDClosure(globals.ns, &attributesOf,          "attributesOf");
// 		globals["isNull"d] =          new MDClosure(globals.ns, &isParam!("null"),      "isNull");
// 		globals["isBool"d] =          new MDClosure(globals.ns, &isParam!("bool"),      "isBool");
// 		globals["isInt"d] =           new MDClosure(globals.ns, &isParam!("int"),       "isInt");
// 		globals["isFloat"d] =         new MDClosure(globals.ns, &isParam!("float"),     "isFloat");
// 		globals["isChar"d] =          new MDClosure(globals.ns, &isParam!("char"),      "isChar");
// 		globals["isString"d] =        new MDClosure(globals.ns, &isParam!("string"),    "isString");
// 		globals["isTable"d] =         new MDClosure(globals.ns, &isParam!("table"),     "isTable");
// 		globals["isArray"d] =         new MDClosure(globals.ns, &isParam!("array"),     "isArray");
// 		globals["isFunction"d] =      new MDClosure(globals.ns, &isParam!("function"),  "isFunction");
// 		globals["isObject"d] =        new MDClosure(globals.ns, &isParam!("object"),    "isObject");
// 		globals["isNamespace"d] =     new MDClosure(globals.ns, &isParam!("namespace"), "isNamespace");
// 		globals["isThread"d] =        new MDClosure(globals.ns, &isParam!("thread"),    "isThread");
// 
// 		// Conversions
		register(t, "toString", &toString);
		register(t, "rawToString", &rawToString);
		register(t, "toBool", &toBool);
		register(t, "toInt", &toInt);
		register(t, "toFloat", &toFloat);
		register(t, "toChar", &toChar);
		register(t, "format", &format);

		// Console IO
		register(t, "write", &write);
		register(t, "writeln", &writeln);
		register(t, "writef", &writef);
		register(t, "writefln", &writefln);

		newTable(t);
		register(t, "dumpVal", &dumpVal, 1);

// 		register(t, "readln", &readln);

// 		// Dynamic compilation stuff
// 		globals["loadString"d] =      new MDClosure(globals.ns, &loadString,            "loadString");
// 		globals["eval"d] =            new MDClosure(globals.ns, &eval,                  "eval");
// 		globals["loadJSON"d] =        new MDClosure(globals.ns, &loadJSON,              "loadJSON");
// 		globals["toJSON"d] =          new MDClosure(globals.ns, &toJSON,                "toJSON");
// 
// 		// The Namespace type's metatable
// 		MDNamespace namespace = new MDNamespace("namespace"d, globals.ns);
// 
// 		namespace.addList
// 		(
// 			"opApply"d, new MDClosure(namespace, &namespaceApply,  "namespace.opApply")
// 		);
// 
// 		context.setMetatable(MDValue.Type.Namespace, namespace);
// 
// 		// The Thread type's metatable
// 		MDNamespace thread = new MDNamespace("thread"d, globals.ns);
// 
// 		thread.addList
// 		(
// 			"reset"d,       new MDClosure(thread, &threadReset, "thread.reset"),
// 			"state"d,       new MDClosure(thread, &threadState, "thread.state"),
// 			"isInitial"d,   new MDClosure(thread, &isInitial,   "thread.isInitial"),
// 			"isRunning"d,   new MDClosure(thread, &isRunning,   "thread.isRunning"),
// 			"isWaiting"d,   new MDClosure(thread, &isWaiting,   "thread.isWaiting"),
// 			"isSuspended"d, new MDClosure(thread, &isSuspended, "thread.isSuspended"),
// 			"isDead"d,      new MDClosure(thread, &isDead,      "thread.isDead"),
// 			"opApply"d,     new MDClosure(thread, &threadApply, "thread.opApply",
// 			[
// 				MDValue(new MDClosure(thread, &threadIterator, "thread.iterator"))
// 			])
// 		);
// 
// 		context.setMetatable(MDValue.Type.Thread, thread);
// 
// 		// The Function type's metatable
// 		MDNamespace func = new MDNamespace("function"d, globals.ns);
// 		
// 		func.addList
// 		(
// 			"environment"d, new MDClosure(func, &functionEnvironment, "function.environment"),
// 			"isNative"d,    new MDClosure(func, &functionIsNative,    "function.isNative"),
// 			"numParams"d,   new MDClosure(func, &functionNumParams,   "function.numParams"),
// 			"isVararg"d,    new MDClosure(func, &functionIsVararg,    "function.isVararg")
// 		);
// 
// 		context.setMetatable(MDValue.Type.Function, func);
	}

	// ===================================================================================================================================
	// Object

	nuint objectClone(MDThread* t, nuint numParams)
	{
		newObject(t, 0);
		return 1;
	}
	
/*
	// ===================================================================================================================================
	// Basic functions

	nuint getTraceback(MDThread* t, nuint numParams)
	{
		s.push(new MDString(s.context.getTracebackString()));
		return 1;
	}

	nuint haltThread(MDThread* t, nuint numParams)
	{
		if(numParams == 0)
			s.halt();
		else
		{
			auto thread = s.getParam!(MDState)(0);
			thread.pendingHalt();
			s.call(thread, 0);
		}

		return 0;
	}
*/

	nuint currentThread(MDThread* t, nuint numParams)
	{
		if(t is mainThread(getVM(t)))
			pushNull(t);
		else
			pushThread(t, t);

		return 1;
	}

/*
	nuint setModuleLoader(MDThread* t, nuint numParams)
	{
		s.context.setModuleLoader(s.getParam!(dchar[])(0), s.getParam!(MDClosure)(1));
		return 0;
	}

	nuint reloadModule(MDThread* t, nuint numParams)
	{
		s.push(s.context.reloadModule(s.getParam!(MDString)(0).mData, s));
		return 1;
	}

	nuint removeKey(MDThread* t, nuint numParams)
	{
		MDValue container = s.getParam(0u);

		if(container.isTable())
		{
			MDValue key = s.getParam(1u);
			
			if(key.isNull)
				s.throwRuntimeException("Table key cannot be null");
				
			container.as!(MDTable).remove(key);
		}
		else if(container.isNamespace())
		{
			MDNamespace ns = container.as!(MDNamespace);
			MDString key = s.getParam!(MDString)(1);

			if(!(key in ns))
				s.throwRuntimeException("Key '{}' does not exist in namespace '{}'", key, ns.nameString());

			ns.remove(key);
		}
		else
			s.throwRuntimeException("Container must be a table or namespace");

		return 0;
	}
*/

	nuint rawSet(MDThread* t, nuint numParams)
	{
		if(numParams < 3)
			throwException(t, "3 parameters expected; only got {}", numParams);

		if(isTable(t, 1))
			idxa(t, 1, true);
		else if(isObject(t, 1))
			fielda(t, 1, true);
		else
		{
			pushTypeString(t, 1);
			throwException(t, "'table' or 'object' expected, not '{}'", getString(t, -1));
		}

		return 0;
	}

	nuint rawGet(MDThread* t, nuint numParams)
	{
		if(numParams < 2)
			throwException(t, "2 parameters expected; only got {}", numParams);

		if(isTable(t, 1))
			idx(t, 1, true);
		else if(isObject(t, 1))
			field(t, 1, true);
		else
		{
			pushTypeString(t, 1);
			throwException(t, "'table' or 'object' expected, not '{}'", getString(t, -1));
		}

		return 1;
	}

	nuint runMain(MDThread* t, nuint numParams)
	{
		checkParam(t, 1, MDValue.Type.Namespace);

		auto main = field(t, 1, "main");

		if(isFunction(t, main))
		{
			insert(t, 1);
			rawCall(t, 1, 0);
		}

		return 0;
	}

	// ===================================================================================================================================
	// Functional stuff

	nuint curry(MDThread* t, nuint numParams)
	{
		static nuint call(MDThread* t, nuint numParams)
		{
			auto funcReg = getUpval(t, 0);
			dup(t, 0);
			getUpval(t, 1);

			for(size_t i = 1; i <= numParams; i++)
				dup(t, i);

			return rawCall(t, funcReg, -1);
		}

		checkParam(t, 1, MDValue.Type.Function);
		checkAnyParam(t, 2);

		newFunction(t, &call, "curryClosure", 2);
		return 1;
	}

	nuint bindContext(MDThread* t, nuint numParams)
	{
		static nuint call(MDThread* t, nuint numParams)
		{
			auto funcReg = getUpval(t, 0);
			getUpval(t, 1);

			for(size_t i = 1; i <= numParams; i++)
				dup(t, i);

			return rawCall(t, funcReg, -1);
		}
		
		checkParam(t, 1, MDValue.Type.Function);
		checkAnyParam(t, 2);

		newFunction(t, &call, "boundFunction", 2);
		return 1;
	}

/*
	// ===================================================================================================================================
	// Reflection-esque stuff

	nuint findGlobal(MDThread* t, nuint numParams)
	{
		auto ns = s.findGlobal(s.getParam!(MDString)(0), 1);

		if(ns is null)
			s.pushNull();
		else
			s.push(ns);

		return 1;
	}

	nuint isSet(MDThread* t, nuint numParams)
	{
		s.push(s.findGlobal(s.getParam!(MDString)(0), 1) !is null);
		return 1;
	}
	
	nuint mdtypeof(MDThread* t, nuint numParams)
	{
		s.push(s.getParam(0u).typeString());
		return 1;
	}

	nuint fieldsOf(MDThread* t, nuint numParams)
	{
		if(s.isParam!("object")(0))
			s.push(s.getParam!(MDObject)(0).fields);
		else
			s.throwRuntimeException("Expected object, not '{}'", s.getParam(0u).typeString());

		return 1;
	}
	
	nuint allFieldsOf(MDThread* t, nuint numParams)
	{
		auto o = s.getParam!(MDObject)(0);

		struct iter
		{
			MDObject obj;
			
			nuint iter(MDThread* t, nuint numParams)
			{
				s.yield(0);

				for(auto o = obj; o !is null; o = o.proto)
					foreach(k, v; o.fields)
						s.yield(0, MDValue(k), v);
						
				return 0;
			}
		}
		
		auto i = new iter;
		i.obj = o;
		s.push(new MDState(s.context, new MDClosure(s.context.globals.ns, &i.iter, "allFieldsOf")));
		
		return 1;
	}

	nuint hasField(MDThread* t, nuint numParams)
	{
		s.push(s.hasField(s.getParam(0u), s.getParam!(MDString)(1)));
		return 1;
	}

	nuint hasMethod(MDThread* t, nuint numParams)
	{
		s.push(s.hasMethod(s.getParam(0u), s.getParam!(MDString)(1)));
		return 1;
	}

	nuint hasAttributes(MDThread* t, nuint numParams)
	{
		MDTable ret;

		if(s.isParam!("function")(0))
			ret = s.getParam!(MDClosure)(0).attributes;
		else if(s.isParam!("object")(0))
			ret = s.getParam!(MDObject)(0).attributes;
		else if(s.isParam!("namespace")(0))
			ret = s.getParam!(MDNamespace)(0).attributes;

		s.push(ret !is null);
		return 1;
	}

	nuint attributesOf(MDThread* t, nuint numParams)
	{
		MDTable ret;

		if(s.isParam!("function")(0))
			ret = s.getParam!(MDClosure)(0).attributes;
		else if(s.isParam!("object")(0))
			ret = s.getParam!(MDObject)(0).attributes;
		else if(s.isParam!("namespace")(0))
			ret = s.getParam!(MDNamespace)(0).attributes;
		else
			s.throwRuntimeException("Expected function, class, or namespace, not '{}'", s.getParam(0u).typeString());

		if(ret is null)
			s.pushNull();
		else
			s.push(ret);

		return 1;
	}
	
	int isParam(char[] type)(MDState s, uint numParams)
	{
		s.push(s.isParam!(type)(0));
		return 1;
	}

	// ===================================================================================================================================
	// Conversions
*/
	nuint toString(MDThread* t, nuint numParams)
	{
		checkAnyParam(t, 1);

		if(isInt(t, 1))
		{
			char style = 'd';

			if(numParams > 1)
				style = getChar(t, 2);

			dchar[80] buffer = void;
			pushString(t, Integer.format(buffer, getInt(t, 1), cast(Integer.Style)style)); // TODO: make this safe
		}
		else
			pushToString(t, 1);

		return 1;
	}

	nuint rawToString(MDThread* t, nuint numParams)
	{
		checkAnyParam(t, 1);
		pushToString(t, 1, true);
		return 1;
	}

	nuint toBool(MDThread* t, nuint numParams)
	{
		checkAnyParam(t, 1);
		pushBool(t, isTrue(t, 1));
		return 1;
	}

	nuint toInt(MDThread* t, nuint numParams)
	{
		checkAnyParam(t, 1);

		switch(type(t, 1))
		{
			case MDValue.Type.Bool:   pushInt(t, cast(mdint)getBool(t, 1)); break;
			case MDValue.Type.Int:    dup(t, 1); break;
			case MDValue.Type.Float:  pushInt(t, cast(mdint)getFloat(t, 1)); break;
			case MDValue.Type.Char:   pushInt(t, cast(mdint)getChar(t, 1)); break;
			case MDValue.Type.String: pushInt(t, cast(mdint)Integer.parse(getString(t, 1), 10)); break; // TODO: make this safe

			default:
				pushTypeString(t, 1);
				throwException(t, "Cannot convert type '{}' to int", getString(t, -1));
		}

		return 1;
	}

	nuint toFloat(MDThread* t, nuint numParams)
	{
		checkAnyParam(t, 1);

		switch(type(t, 1))
		{
			case MDValue.Type.Bool: pushFloat(t, cast(mdfloat)getBool(t, 1)); break;
			case MDValue.Type.Int: pushFloat(t, cast(mdfloat)getInt(t, 1)); break;
			case MDValue.Type.Float: dup(t, 1); break;
			case MDValue.Type.Char: pushFloat(t, cast(mdfloat)getChar(t, 1)); break;
			case MDValue.Type.String: pushFloat(t, cast(mdfloat)Float.parse(getString(t, 1))); break; // TODO: make this safe

			default:
				pushTypeString(t, 1);
				throwException(t, "Cannot convert type '{}' to float", getString(t, -1));
		}

		return 1;
	}

	nuint toChar(MDThread* t, nuint numParams)
	{
		pushChar(t, cast(dchar)checkIntParam(t, 1));
		return 1;
	}

	nuint format(MDThread* t, nuint numParams)
	{
		auto buf = StrBuffer(t);
		formatImpl(t, numParams, &buf.sink);
		buf.finish();
		return 1;
	}

	// ===================================================================================================================================
	// Console IO

	nuint write(MDThread* t, nuint numParams)
	{
		for(size_t i = 1; i <= numParams; i++)
		{
			pushToString(t, i);
			Stdout(getString(t, -1));
		}

		Stdout.flush;
		return 0;
	}

	nuint writeln(MDThread* t, nuint numParams)
	{
		for(size_t i = 1; i <= numParams; i++)
		{
			pushToString(t, i);
			Stdout(getString(t, -1));
		}

		Stdout.newline;
		return 0;
	}

	nuint writef(MDThread* t, nuint numParams)
	{
		uint sink(dchar[] data)
		{
			Stdout(data);
			return data.length;
		}

		formatImpl(t, numParams, &sink);
		Stdout.flush;
		return 0;
	}

	nuint writefln(MDThread* t, nuint numParams)
	{
		uint sink(dchar[] data)
		{
			Stdout(data);
			return data.length;
		}

		formatImpl(t, numParams, &sink);
		Stdout.newline;
		return 0;
	}

	nuint dumpVal(MDThread* t, nuint numParams)
	{
		checkAnyParam(t, 1);
		auto newline = optBoolParam(t, 2, true);

		auto shown = getUpval(t, 0);

		void outputRepr(nint v)
		{
			v = absIndex(t, v);

			// TODO: this
// 			if(s.hasPendingHalt())
// 				throw new MDHaltException();

			void escape(dchar c)
			{
				switch(c)
				{
					case '\'': Stdout(`\'`); break;
					case '\"': Stdout(`\"`); break;
					case '\\': Stdout(`\\`); break;
					case '\a': Stdout(`\a`); break;
					case '\b': Stdout(`\b`); break;
					case '\f': Stdout(`\f`); break;
					case '\n': Stdout(`\n`); break;
					case '\r': Stdout(`\r`); break;
					case '\t': Stdout(`\t`); break;
					case '\v': Stdout(`\v`); break;

					default:
						if(c <= 0x7f && isprint(c))
							Stdout(c);
						else if(c <= 0xFFFF)
							Stdout.format("\\u{:x4}", cast(uint)c);
						else
							Stdout.format("\\U{:x8}", cast(uint)c);
						break;
				}
			}

			void outputArray(nint arr)
			{
				if(opin(t, arr, shown))
				{
					Stdout("[...]");
					return;
				}

				dup(t, arr);
				pushBool(t, true);
				idxa(t, shown);

				scope(exit)
				{
					dup(t, arr);
					pushNull(t);
					idxa(t, shown);
				}

				Stdout('[');
				
				auto length = len(t, arr);

				if(length > 0)
				{
					pushInt(t, 0);
					idx(t, arr);
					outputRepr(-1);
					pop(t);

					for(size_t i = 1; i < length; i++)
					{
						// TODO: this
// 						if(s.hasPendingHalt())
// 							throw new MDHaltException();

						Stdout(", ");
						pushInt(t, i);
						idx(t, arr);
						outputRepr(-1);
						pop(t);
					}
				}

				Stdout(']');
			}

			void outputTable(nint tab)
			{
				if(opin(t, tab, shown))
				{
					Stdout("{...}");
					return;
				}
				
				dup(t, tab);
				pushBool(t, true);
				idxa(t, shown);
				
				scope(exit)
				{
					dup(t, tab);
					pushNull(t);
					idxa(t, shown);
				}

				Stdout('{');
				
				auto length = len(t, tab);

				// TODO: this
// 				if(length > 0)
// 				{
// 					if(length == 1)
// 					{
// 						foreach(k, v; t)
// 						{
// 							if(s.hasPendingHalt())
// 								throw new MDHaltException();
// 
// 							Stdout('[');
// 							outputRepr(k);
// 							Stdout("] = ");
// 							outputRepr(v);
// 						}
// 					}
// 					else
// 					{
// 						bool first = true;
// 	
// 						foreach(k, v; t)
// 						{
// 							if(first)
// 								first = !first;
// 							else
// 								Stdout(", ");
// 								
// 							if(s.hasPendingHalt())
// 								throw new MDHaltException();
// 	
// 							Stdout('[');
// 							outputRepr(k);
// 							Stdout("] = ");
// 							outputRepr(v);
// 						}
// 					}
// 				}
				Stdout('!');

				Stdout('}');
			}

			if(isString(t, v))
			{
				Stdout('"');
				
				foreach(c; getString(t, v))
					escape(c);

				Stdout('"');
			}
			else if(isChar(t, v))
			{
				Stdout("'");
				escape(getChar(t, v));
				Stdout("'");
			}
			else if(isArray(t, v))
				outputArray(v);
			else if(isTable(t, v) && !hasMethod(t, v, "toString"))
				outputTable(v);
			else
			{
				pushToString(t, v);
				Stdout(getString(t, -1));
				pop(t);
			}
		}

		outputRepr(1);
		
		if(newline)
			Stdout.newline;

		return 0;
	}

/*
	nuint readln(MDThread* t, nuint numParams)
	{
		pushString(t, Cin.copyln());
		return 1;
	}

/*
	// ===================================================================================================================================
	// Dynamic Compilation

	nuint loadString(MDThread* t, nuint numParams)
	{
		char[] name;
		MDNamespace env;

		if(numParams > 1)
		{
			if(s.isParam!("string")(1))
			{
				name = s.getParam!(char[])(1);

				if(numParams > 2)
					env = s.getParam!(MDNamespace)(2);
				else
					env = s.environment(1);
			}
			else
				env = s.getParam!(MDNamespace)(1);
		}
		else
		{
			name = "<loaded by loadString>";
			env = s.environment(1);
		}

		MDFuncDef def = Compiler().compileStatements(s.getParam!(dchar[])(0), name);
		s.push(new MDClosure(env, def));
		return 1;
	}
	
	nuint eval(MDThread* t, nuint numParams)
	{
		MDFuncDef def = Compiler().compileExpression(s.getParam!(dchar[])(0), "<loaded by eval>");
		MDNamespace env;

		if(numParams > 1)
			env = s.getParam!(MDNamespace)(1);
		else
			env = s.environment(1);

		return s.call(new MDClosure(env, def), -1);
	}
	
	nuint loadJSON(MDThread* t, nuint numParams)
	{
		s.push(Compiler().loadJSON(s.getParam!(dchar[])(0)));
		return 1;
	}

	nuint toJSON(MDThread* t, nuint numParams)
	{
		MDValue root = s.getParam(0u);
		bool pretty = false;

		if(numParams > 1)
			pretty = s.getParam!(bool)(1);

		scope cond = new GrowBuffer();
		scope printer = new Print!(dchar)(FormatterD, cond);

		toJSONImpl(s, root, pretty, printer);

		s.push(cast(dchar[])cond.slice());
		return 1;
	}

	// ===================================================================================================================================
	// Namespace metatable

	nuint namespaceIterator(MDThread* t, nuint numParams)
	{
		MDNamespace namespace = s.getUpvalue!(MDNamespace)(0);
		MDArray keys = s.getUpvalue!(MDArray)(1);
		int index = s.getUpvalue!(int)(2);

		index++;
		s.setUpvalue(2u, index);

		if(index >= keys.length)
			return 0;

		s.push(keys[index]);
		s.push(namespace[keys[index].as!(MDString)]);

		return 2;
	}

	nuint namespaceApply(MDThread* t, nuint numParams)
	{
		MDNamespace ns = s.getContext!(MDNamespace);

		MDValue[3] upvalues;
		upvalues[0] = ns;
		upvalues[1] = ns.keys;
		upvalues[2] = -1;

		s.push(s.context.newClosure(&namespaceIterator, "namespaceIterator", upvalues));
		return 1;
	}

	// ===================================================================================================================================
	// Thread metatable

	nuint threadReset(MDThread* t, nuint numParams)
	{
		MDClosure cl;

		if(numParams > 0)
			cl = s.getParam!(MDClosure)(0);

		s.getContext!(MDState).reset(cl);
		return 0;
	}

	nuint threadState(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDState).stateString());
		return 1;
	}
	
	nuint isInitial(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDState).state() == MDState.State.Initial);
		return 1;
	}

	nuint isRunning(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDState).state() == MDState.State.Running);
		return 1;
	}

	nuint isWaiting(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDState).state() == MDState.State.Waiting);
		return 1;
	}

	nuint isSuspended(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDState).state() == MDState.State.Suspended);
		return 1;
	}

	nuint isDead(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDState).state() == MDState.State.Dead);
		return 1;
	}
	
	nuint threadIterator(MDThread* t, nuint numParams)
	{
		MDState thread = s.getContext!(MDState);
		int index = s.getParam!(int)(0);
		index++;

		s.push(index);
		
		uint threadIdx = s.push(thread);
		s.pushNull();
		uint numRets = s.rawCall(threadIdx, -1) + 1;

		if(thread.state == MDState.State.Dead)
			return 0;

		return numRets;
	}

	nuint threadApply(MDThread* t, nuint numParams)
	{
		MDState thread = s.getContext!(MDState);
		MDValue init = s.getParam(0u);

		if(thread.state != MDState.State.Initial)
			s.throwRuntimeException("Iterated coroutine must be in the initial state");

		uint funcReg = s.push(thread);
		s.push(thread);
		s.push(init);
		s.rawCall(funcReg, 0);

		s.push(s.getUpvalue(0u));
		s.push(thread);
		s.push(-1);
		return 3;
	}

	// ===================================================================================================================================
	// Function metatable

	nuint functionEnvironment(MDThread* t, nuint numParams)
	{
		MDClosure cl = s.getContext!(MDClosure);
		
		s.push(cl.environment);

		if(numParams > 0)
			cl.environment = s.getParam!(MDNamespace)(0);

		return 1;
	}
	
	nuint functionIsNative(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDClosure).isNative);
		return 1;
	}
	
	nuint functionNumParams(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDClosure).numParams);
		return 1;
	}
	
	nuint functionIsVararg(MDThread* t, nuint numParams)
	{
		s.push(s.getContext!(MDClosure).isVararg);
		return 1;
	}

	// ===================================================================================================================================
	// StringBuffer

	static class MDStringBufferClass : MDObject
	{
		MDClosure iteratorClosure;
		MDClosure iteratorReverseClosure;

		public this(MDObject owner)
		{
			super("StringBuffer", owner);

			iteratorClosure = new MDClosure(fields, &iterator, "StringBuffer.iterator");
			iteratorReverseClosure = new MDClosure(fields, &iteratorReverse, "StringBuffer.iteratorReverse");
			auto catEq = new MDClosure(fields, &opCatAssign, "StringBuffer.opCatAssign");

			fields.addList
			(
				"clone"d,          new MDClosure(fields, &clone,          "StringBuffer.clone"),
				"append"d,         catEq,
				"opCatAssign"d,    catEq,
				"insert"d,         new MDClosure(fields, &insert,         "StringBuffer.insert"),
				"remove"d,         new MDClosure(fields, &remove,         "StringBuffer.remove"),
				"toString"d,       new MDClosure(fields, &toString,       "StringBuffer.toString"),
				"opLengthAssign"d, new MDClosure(fields, &opLengthAssign, "StringBuffer.opLengthAssign"),
				"opLength"d,       new MDClosure(fields, &opLength,       "StringBuffer.opLength"),
				"opIndex"d,        new MDClosure(fields, &opIndex,        "StringBuffer.opIndex"),
				"opIndexAssign"d,  new MDClosure(fields, &opIndexAssign,  "StringBuffer.opIndexAssign"),
				"opApply"d,        new MDClosure(fields, &opApply,        "StringBuffer.opApply"),
				"opSlice"d,        new MDClosure(fields, &opSlice,        "StringBuffer.opSlice"),
				"opSliceAssign"d,  new MDClosure(fields, &opSliceAssign,  "StringBuffer.opSliceAssign"),
				"reserve"d,        new MDClosure(fields, &reserve,        "StringBuffer.reserve"),
				"format"d,         new MDClosure(fields, &format,         "StringBuffer.format"),
				"formatln"d,       new MDClosure(fields, &formatln,       "StringBuffer.formatln")
			);
		}

		public nuint clone(MDThread* t, nuint numParams)
		{
			MDStringBuffer ret;

			if(numParams > 0)
			{
				if(s.isParam!("int")(0))
					ret = new MDStringBuffer(this, s.getParam!(uint)(0));
				else if(s.isParam!("string")(0))
					ret = new MDStringBuffer(this, s.getParam!(dchar[])(0));
				else
					s.throwRuntimeException("'int' or 'string' expected for constructor, not '{}'", s.getParam(0u).typeString());
			}
			else
				ret = new MDStringBuffer(this);
				
			s.push(ret);
			return 1;
		}

		public nuint opCatAssign(MDThread* t, nuint numParams)
		{
			MDStringBuffer i = s.getContext!(MDStringBuffer);
			
			for(uint j = 0; j < numParams; j++)
			{
				MDValue param = s.getParam(j);

				if(param.isObj)
				{
					if(param.isObject)
					{
						MDStringBuffer other = cast(MDStringBuffer)param.as!(MDObject);
		
						if(other)
						{
							i.append(other);
							continue;
						}
					}
		
					i.append(s.valueToString(param));
				}
				else
					i.append(param.toString());
			}
			
			return 0;
		}

		public nuint insert(MDThread* t, nuint numParams)
		{
			MDStringBuffer i = s.getContext!(MDStringBuffer);
			MDValue param = s.getParam(1u);

			if(param.isObj)
			{
				if(param.isObject)
				{
					MDStringBuffer other = cast(MDStringBuffer)param.as!(MDObject);
					
					if(other)
					{
						i.insert(s.getParam!(int)(0), other);
						return 0;
					}
				}
				
				i.insert(s.getParam!(int)(0), s.valueToString(param));
			}
			else
				i.insert(s.getParam!(int)(0), param.toString());

			return 0;
		}

		public nuint remove(MDThread* t, nuint numParams)
		{
			MDStringBuffer i = s.getContext!(MDStringBuffer);
			uint start = s.getParam!(uint)(0);
			uint end = start + 1;

			if(numParams > 1)
				end = s.getParam!(uint)(1);

			i.remove(start, end);
			return 0;
		}
		
		public nuint toString(MDThread* t, nuint numParams)
		{
			s.push(s.getContext!(MDStringBuffer).toMDString());
			return 1;
		}
		
		public nuint opLengthAssign(MDThread* t, nuint numParams)
		{
			int newLen = s.getParam!(int)(0);
			
			if(newLen < 0)
				s.throwRuntimeException("Invalid length ({})", newLen);

			s.getContext!(MDStringBuffer).length = newLen;
			return 0;
		}

		public nuint opLength(MDThread* t, nuint numParams)
		{
			s.push(s.getContext!(MDStringBuffer).length);
			return 1;
		}
		
		public nuint opIndex(MDThread* t, nuint numParams)
		{
			s.push(s.getContext!(MDStringBuffer)()[s.getParam!(int)(0)]);
			return 1;
		}

		public nuint opIndexAssign(MDThread* t, nuint numParams)
		{
			s.getContext!(MDStringBuffer)()[s.getParam!(int)(0)] = s.getParam!(dchar)(1);
			return 0;
		}

		public nuint iterator(MDThread* t, nuint numParams)
		{
			MDStringBuffer i = s.getContext!(MDStringBuffer);
			int index = s.getParam!(int)(0);

			index++;

			if(index >= i.length)
				return 0;

			s.push(index);
			s.push(i[index]);

			return 2;
		}
		
		public nuint iteratorReverse(MDThread* t, nuint numParams)
		{
			MDStringBuffer i = s.getContext!(MDStringBuffer);
			int index = s.getParam!(int)(0);
			
			index--;
	
			if(index < 0)
				return 0;
				
			s.push(index);
			s.push(i[index]);
			
			return 2;
		}
		
		public nuint opApply(MDThread* t, nuint numParams)
		{
			MDStringBuffer i = s.getContext!(MDStringBuffer);

			if(s.isParam!("string")(0) && s.getParam!(MDString)(0) == "reverse"d)
			{
				s.push(iteratorReverseClosure);
				s.push(i);
				s.push(cast(int)i.length);
			}
			else
			{
				s.push(iteratorClosure);
				s.push(i);
				s.push(-1);
			}

			return 3;
		}

		public nuint opSlice(MDThread* t, nuint numParams)
		{
			s.push(s.getContext!(MDStringBuffer)()[s.getParam!(int)(0) .. s.getParam!(int)(1)]);
			return 1;
		}
		
		public nuint opSliceAssign(MDThread* t, nuint numParams)
		{
			s.getContext!(MDStringBuffer)()[s.getParam!(int)(0) .. s.getParam!(int)(1)] = s.getParam!(dchar[])(2);
			return 0;
		}

		public nuint reserve(MDThread* t, nuint numParams)
		{
			s.getContext!(MDStringBuffer).reserve(s.getParam!(uint)(0));
			return 0;
		}
		
		public nuint format(MDThread* t, nuint numParams)
		{
			auto self = s.getContext!(MDStringBuffer);

			uint sink(dchar[] data)
			{
				self.append(data);
				return data.length;
			}

			formatImpl(s, s.getAllParams(), &sink);
			return 0;
		}

		public nuint formatln(MDThread* t, nuint numParams)
		{
			auto self = s.getContext!(MDStringBuffer);

			uint sink(dchar[] data)
			{
				self.append(data);
				return data.length;
			}

			formatImpl(s, s.getAllParams(), &sink);
			self.append("\n"d);
			return 0;
		}
	}

	static class MDStringBuffer : MDObject
	{
		protected dchar[] mBuffer;
		protected size_t mLength = 0;

		public this(MDStringBufferClass owner)
		{
			super("StringBuffer", owner);
			mBuffer = new dchar[32];
		}

		public this(MDStringBufferClass owner, size_t size)
		{
			super("StringBuffer", owner);
			mBuffer = new dchar[size];
		}

		public this(MDStringBufferClass owner, dchar[] data)
		{
			super("StringBuffer", owner);
			mBuffer = data;
			mLength = mBuffer.length;
		}
		
		public void append(MDStringBuffer other)
		{
			resize(other.mLength);
			mBuffer[mLength .. mLength + other.mLength] = other.mBuffer[0 .. other.mLength];
			mLength += other.mLength;
		}

		public void append(MDString str)
		{
			resize(str.mData.length);
			mBuffer[mLength .. mLength + str.mData.length] = str.mData[];
			mLength += str.mData.length;
		}
		
		public void append(char[] s)
		{
			append(utf.toString32(s));
		}
		
		public void append(dchar[] s)
		{
			resize(s.length);
			mBuffer[mLength .. mLength + s.length] = s[];
			mLength += s.length;
		}
		
		public void insert(int offset, MDStringBuffer other)
		{
			if(offset > mLength)
				throw new MDException("Offset out of bounds: {}", offset);

			resize(other.mLength);
			
			for(int i = mLength + other.mLength - 1, j = mLength - 1; j >= offset; i--, j--)
				mBuffer[i] = mBuffer[j];
				
			mBuffer[offset .. offset + other.mLength] = other.mBuffer[0 .. other.mLength];
			mLength += other.mLength;
		}
		
		public void insert(int offset, MDString str)
		{
			if(offset > mLength)
				throw new MDException("Offset out of bounds: {}", offset);

			resize(str.mData.length);

			for(int i = mLength + str.mData.length - 1, j = mLength - 1; j >= offset; i--, j--)
				mBuffer[i] = mBuffer[j];

			mBuffer[offset .. offset + str.mData.length] = str.mData[];
			mLength += str.mData.length;
		}

		public void insert(int offset, char[] s)
		{
			if(offset > mLength)
				throw new MDException("Offset out of bounds: {}", offset);

			dchar[] str = utf.toString32(s);
			resize(str.length);

			for(int i = mLength + str.length - 1, j = mLength - 1; j >= offset; i--, j--)
				mBuffer[i] = mBuffer[j];

			mBuffer[offset .. offset + str.length] = str[];
			mLength += str.length;
		}
		
		public void remove(uint start, uint end)
		{
			if(end > mLength)
				end = mLength;

			if(start > mLength || start > end)
				throw new MDException("Invalid indices: {} .. {}", start, end);

			for(int i = start, j = end; j < mLength; i++, j++)
				mBuffer[i] = mBuffer[j];

			mLength -= (end - start);
		}
		
		public MDString toMDString()
		{
			return new MDString(mBuffer[0 .. mLength]);
		}
		
		public void length(uint len)
		{
			uint oldLength = mLength;
			mLength = len;

			if(mLength > mBuffer.length)
				mBuffer.length = mLength;
				
			if(mLength > oldLength)
				mBuffer[oldLength .. mLength] = dchar.init;
		}
		
		public uint length()
		{
			return mLength;
		}
		
		public dchar opIndex(int index)
		{
			if(index < 0)
				index += mLength;

			if(index < 0 || index >= mLength)
				throw new MDException("Invalid index: {}", index);

			return mBuffer[index];
		}

		public void opIndexAssign(dchar c, int index)
		{
			if(index < 0)
				index += mLength;

			if(index >= mLength)
				throw new MDException("Invalid index: {}", index);

			mBuffer[index] = c;
		}

		public dchar[] opSlice(int lo, int hi)
		{
			if(lo < 0)
				lo += mLength;

			if(hi < 0)
				hi += mLength;

			if(lo < 0 || lo > hi || hi >= mLength)
				throw new MDException("Invalid indices: {} .. {}", lo, hi);

			return mBuffer[lo .. hi];
		}

		public void opSliceAssign(dchar[] s, int lo, int hi)
		{
			if(lo < 0)
				lo += mLength;

			if(hi < 0)
				hi += mLength;

			if(lo < 0 || lo > hi || hi >= mLength)
				throw new MDException("Invalid indices: {} .. {}", lo, hi);

			if(hi - lo != s.length)
				throw new MDException("Slice length ({}) does not match length of string ({})", hi - lo, s.length);

			mBuffer[lo .. hi] = s[];
		}
		
		public void reserve(int size)
		{
			if(size > mBuffer.length)
				mBuffer.length = size;
		}

		protected void resize(uint length)
		{
			if(length > (mBuffer.length - mLength))
				mBuffer.length = mBuffer.length + length;
		}
	}

*/
}