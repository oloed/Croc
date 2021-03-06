/******************************************************************************
This module contains the 'stream' standard library.

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

module croc.stdlib_stream;

import tango.core.Traits;
import tango.io.Console;
import tango.io.device.Conduit;
import tango.io.stream.Format;
import tango.io.stream.Lines;
import tango.math.Math;

import croc.api_interpreter;
import croc.api_stack;
import croc.ex;
import croc.ex_format;
import croc.types;
import croc.vm;

struct StreamLib
{
static:
	void init(CrocThread* t)
	{
		makeModule(t, "stream", function uword(CrocThread* t)
		{
			InStreamObj.init(t);
			OutStreamObj.init(t);
			InoutStreamObj.init(t);
			MemInStreamObj.init(t);
			MemOutStreamObj.init(t);
			MemInoutStreamObj.init(t);

			return 0;
		});

		importModuleNoNS(t, "stream");
	}
}

struct InStreamObj
{
static:
	enum Fields
	{
		stream,
		lines
	}

	align(1) struct Members
	{
		InputStream stream;
		Lines!(char) lines;
		bool closed = true;
		bool closable = true;
	}

	InputStream getStream(CrocThread* t, word idx)
	{
		return checkInstParam!(Members)(t, idx, "stream.InStream").stream;
	}

	InputStream getOpenStream(CrocThread* t, word idx)
	{
		auto ret = checkInstParam!(Members)(t, idx, "stream.InStream");

		if(ret.closed)
			throwStdException(t, "ValueException", "Attempting to perform operation on a closed stream");

		return ret.stream;
	}

	void init(CrocThread* t)
	{
		CreateClass(t, "InStream", (CreateClass* c)
		{
			c.method("constructor",  2, &constructor);

			mixin(ReadFuncDefs);
			mixin(CommonFuncDefs);
		});

		newFunction(t, &allocator, "InStream.allocator");
		setAllocator(t, -2);

		newFunction(t, &finalizer, "InStream.finalizer");
		setFinalizer(t, -2);

		newGlobal(t, "InStream");
	}

	Members* getThis(CrocThread* t)
	{
		return checkInstParam!(Members)(t, 0, "InStream");
	}

	Members* getOpenThis(CrocThread* t)
	{
		auto ret = checkInstParam!(Members)(t, 0, "InStream");

		if(ret.closed)
			throwStdException(t, "ValueException", "Attempting to perform operation on a closed stream");

		return ret;
	}

	uword allocator(CrocThread* t)
	{
		newInstance(t, 0, Fields.max + 1, Members.sizeof);
		*(cast(Members*)getExtraBytes(t, -1).ptr) = Members.init;

		dup(t);
		pushNull(t);
		rotateAll(t, 3);
		methodCall(t, 2, "constructor", 0);
		return 1;
	}

	uword finalizer(CrocThread* t)
	{
		auto memb = cast(Members*)getExtraBytes(t, 0).ptr;

		if(memb.closable && !memb.closed)
		{
			memb.closed = true;
			safeCode(t, "exceptions.IOException", memb.stream.close());
		}

		return 0;
	}

	uword constructor(CrocThread* t)
	{
		auto memb = getThis(t);

		if(memb.stream !is null)
			throwStdException(t, "ValueException", "Attempting to call constructor on an already-initialized InStream");

		checkParam(t, 1, CrocValue.Type.NativeObj);
		auto input = cast(InputStream)getNativeObj(t, 1);

		if(input is null)
			throwStdException(t, "ValueException", "instances of InStream may only be created using instances of the Tango InputStream");

		memb.closable = optBoolParam(t, 2, true);
		memb.stream = input;
		memb.lines = new Lines!(char)(memb.stream);
		memb.closed = false;

		pushNativeObj(t, cast(Object)memb.stream); setExtraVal(t, 0, Fields.stream);
		pushNativeObj(t, memb.lines);              setExtraVal(t, 0, Fields.lines);

		return 0;
	}

	mixin ReadFuncs!(false);
	mixin CommonFuncs!(false, false);
}

struct OutStreamObj
{
static:
	enum Fields
	{
		stream,
		print
	}

	align(1) struct Members
	{
		OutputStream stream;
		FormatOutput!(char) print;
		bool closed = true;
		bool closable = true;
	}

	OutputStream getStream(CrocThread* t, word idx)
	{
		return checkInstParam!(Members)(t, idx, "stream.OutStream").stream;
	}

	OutputStream getOpenStream(CrocThread* t, word idx)
	{
		auto ret = checkInstParam!(Members)(t, idx, "stream.OutStream");

		if(ret.closed)
			throwStdException(t, "ValueException", "Attempting to perform operation on a closed stream");

		return ret.stream;
	}

	void init(CrocThread* t)
	{
		CreateClass(t, "OutStream", (CreateClass* c)
		{
			c.method("constructor",   2, &constructor);
			
			mixin(WriteFuncDefs);
			mixin(CommonFuncDefs);
		});

		newFunction(t, &allocator, "OutStream.allocator");
		setAllocator(t, -2);

		newFunction(t, &finalizer, "OutStream.finalizer");
		setFinalizer(t, -2);

		newGlobal(t, "OutStream");
	}

	Members* getThis(CrocThread* t)
	{
		return checkInstParam!(Members)(t, 0, "OutStream");
	}

	Members* getOpenThis(CrocThread* t)
	{
		auto ret = checkInstParam!(Members)(t, 0, "OutStream");

		if(ret.closed)
			throwStdException(t, "ValueException", "Attempting to perform operation on a closed stream");

		return ret;
	}

	uword allocator(CrocThread* t)
	{
		newInstance(t, 0, Fields.max + 1, Members.sizeof);
		*(cast(Members*)getExtraBytes(t, -1).ptr) = Members.init;

		dup(t);
		pushNull(t);
		rotateAll(t, 3);
		methodCall(t, 2, "constructor", 0);
		return 1;
	}

	uword finalizer(CrocThread* t)
	{
		auto memb = cast(Members*)getExtraBytes(t, 0).ptr;

		if(memb.closable && !memb.closed)
		{
			memb.closed = true;
			safeCode(t, "exceptions.IOException", memb.stream.flush());
			safeCode(t, "exceptions.IOException", memb.stream.close());
		}

		return 0;
	}

	uword constructor(CrocThread* t)
	{
		auto memb = getThis(t);

		if(memb.stream !is null)
			throwStdException(t, "ValueException", "Attempting to call constructor on an already-initialized OutStream");

		checkParam(t, 1, CrocValue.Type.NativeObj);
		auto output = cast(OutputStream)getNativeObj(t, 1);

		if(output is null)
			throwStdException(t, "ValueException", "instances of OutStream may only be created using instances of the Tango OutputStream");

		memb.closable = optBoolParam(t, 2, true);
		memb.stream = output;
		memb.print = new FormatOutput!(char)(t.vm.formatter, memb.stream);
		memb.closed = false;

		pushNativeObj(t, cast(Object)memb.stream); setExtraVal(t, 0, Fields.stream);
		pushNativeObj(t, memb.print);              setExtraVal(t, 0, Fields.print);

		return 0;
	}

	mixin WriteFuncs!(false);
	mixin CommonFuncs!(false, true);
}

struct InoutStreamObj
{
static:
	enum Fields
	{
		stream,
		lines,
		print
	}

	align(1) struct Members
	{
		IConduit stream;
		Lines!(char) lines;
		FormatOutput!(char) print;
		bool closed = true;
		bool closable = true;
		bool dirty = false;
	}

	IConduit getStream(CrocThread* t, word idx)
	{
		return checkInstParam!(Members)(t, idx, "stream.InoutStream").stream;
	}

	IConduit getOpenStream(CrocThread* t, word idx)
	{
		auto ret = checkInstParam!(Members)(t, idx, "stream.InoutStream");

		if(ret.closed)
			throwStdException(t, "ValueException", "Attempting to perform operation on a closed stream");

		return ret.stream;
	}

	void init(CrocThread* t)
	{
		CreateClass(t, "Stream", (CreateClass* c)
		{
			c.method("constructor", 2, &constructor);

			mixin(ReadFuncDefs);
			mixin(WriteFuncDefs);
			mixin(CommonFuncDefs);
		});

		newFunction(t, &allocator, "InoutStream.allocator");
		setAllocator(t, -2);

		newFunction(t, &finalizer, "InoutStream.finalizer");
		setFinalizer(t, -2);

		newGlobal(t, "InoutStream");
	}

	Members* getThis(CrocThread* t)
	{
		return checkInstParam!(Members)(t, 0, "InoutStream");
	}

	Members* getOpenThis(CrocThread* t)
	{
		auto ret = checkInstParam!(Members)(t, 0, "InoutStream");

		if(ret.closed)
			throwStdException(t, "ValueException", "Attempting to perform operation on a closed stream");

		return ret;
	}

	uword allocator(CrocThread* t)
	{
		newInstance(t, 0, Fields.max + 1, Members.sizeof);
		*(cast(Members*)getExtraBytes(t, -1).ptr) = Members.init;

		dup(t);
		pushNull(t);
		rotateAll(t, 3);
		methodCall(t, 2, "constructor", 0);
		return 1;
	}

	uword finalizer(CrocThread* t)
	{
		auto memb = cast(Members*)getExtraBytes(t, 0).ptr;

		if(memb.closable && !memb.closed)
		{
			memb.closed = true;

			if(memb.dirty)
			{
				safeCode(t, "exceptions.IOException", memb.stream.flush());
				memb.dirty = false;
			}

			safeCode(t, "exceptions.IOException", memb.stream.close());
		}

		return 0;
	}

	uword constructor(CrocThread* t)
	{
		auto memb = getThis(t);

		if(memb.stream !is null)
			throwStdException(t, "ValueException", "Attempting to call constructor on an already-initialized InoutStream");

		checkParam(t, 1, CrocValue.Type.NativeObj);
		auto stream = cast(IConduit)getNativeObj(t, 1);

		if(stream is null)
			throwStdException(t, "ValueException", "instances of Stream may only be created using instances of Tango's IConduit");

		memb.closable = optBoolParam(t, 2, true);
		memb.stream = stream;
		memb.lines = new Lines!(char)(memb.stream);
		memb.print = new FormatOutput!(char)(t.vm.formatter, memb.stream);
		memb.closed = false;

		pushNativeObj(t, cast(Object)memb.stream); setExtraVal(t, 0, Fields.stream);
		pushNativeObj(t, memb.lines);              setExtraVal(t, 0, Fields.lines);
		pushNativeObj(t, memb.print);              setExtraVal(t, 0, Fields.print);

		return 0;
	}

	void checkDirty(CrocThread* t, Members* memb)
	{
		if(memb.dirty)
		{
			memb.dirty = false;
			safeCode(t, "exceptions.IOException", memb.stream.flush());
		}
	}

	mixin ReadFuncs!(true);
	mixin WriteFuncs!(true);
	mixin CommonFuncs!(true, false);
}

class MemblockConduit : Conduit, Conduit.Seek
{
private:
	CrocVM* vm;
	ulong mMB;
	uword mPos = 0;

	this(CrocVM* vm, ulong mb)
	{
		super();
		this.vm = vm;
		mMB = mb;
	}

public:
	override char[] toString()
	{
		return "<memblock>";
	}

	override uword bufferSize()
	{
		return 1024;
	}

	override void detach()
	{

	}

	override uword read(void[] dest)
	{
		auto t = currentThread(vm);
		pushRef(t, mMB);
		auto mb = getMemblock(t, -1);
		pop(t);

		auto data = mb.data;

		if(mPos >= data.length)
			return Eof;

		auto numBytes = min(data.length - mPos, dest.length);
		dest[0 .. numBytes] = data[mPos .. mPos + numBytes];
		mPos += numBytes;
		return numBytes;
	}

	override uword write(void[] src)
	{
		auto t = currentThread(vm);
		pushRef(t, mMB);
		auto mb = getMemblock(t, -1);

		auto data = mb.data;

		if(src.length > data.length - mPos)
			lenai(t, -1, mPos + src.length);

		pop(t);

		data[mPos .. mPos + src.length] = cast(ubyte[])src[];
		mPos += src.length;
		return src.length;
	}

	override long seek(long offset, Anchor anchor = Anchor.Begin)
	{
		auto t = currentThread(vm);
		pushRef(t, mMB);
		auto mb = getMemblock(t, -1);
		pop(t);

		auto data = mb.data;

		if(offset > data.length)
			offset = data.length;

		switch(anchor)
		{
			case Anchor.Begin:
				mPos = cast(uword)offset;
				break;

			case Anchor.End:
				mPos = cast(uword)(data.length - offset);
				break;

			case Anchor.Current:
				if(offset < 0 && -offset >= mPos)
					mPos = 0;
				else if(offset > 0 && mPos + offset > data.length)
					mPos = data.length;
				else
					mPos += offset;
				break;

			default: assert(false);
		}

		return mPos;
	}
}

struct MemInStreamObj
{
static:
	alias InStreamObj.Members Members;

	void init(CrocThread* t)
	{
		CreateClass(t, "MemInStream", "InStream", (CreateClass* c)
		{
			c.method("constructor", &constructor);
		});

		newFunction(t, &finalizer, "MemInStream.finalizer");
		setFinalizer(t, -2);

		newGlobal(t, "MemInStream");
	}

	uword finalizer(CrocThread* t)
	{
		auto memb = cast(Members*)getExtraBytes(t, 0).ptr;

		if(!memb.closed)
		{
			memb.closed = true;
			removeRef(t, (cast(MemblockConduit)memb.stream).mMB);
		}

		return 0;
	}

	uword constructor(CrocThread* t)
	{
		auto memb = InStreamObj.getThis(t);

		if(memb.stream !is null)
			throwStdException(t, "ValueException", "Attempting to call constructor on an already-initialized MemInStream");

		checkParam(t, 1, CrocValue.Type.Memblock);

		pushNull(t);
		pushNull(t);
		pushNativeObj(t, new MemblockConduit(getVM(t), createRef(t, 1)));
		pushBool(t, true);
		superCall(t, -4, "constructor", 0);

		return 0;
	}
}

struct MemOutStreamObj
{
static:
	alias OutStreamObj.Members Members;

	void init(CrocThread* t)
	{
		CreateClass(t, "MemOutStream", "OutStream", (CreateClass* c)
		{
			c.method("constructor", &constructor);
		});

		newFunction(t, &finalizer, "MemOutStream.finalizer");
		setFinalizer(t, -2);

		newGlobal(t, "MemOutStream");
	}

	uword finalizer(CrocThread* t)
	{
		auto memb = cast(Members*)getExtraBytes(t, 0).ptr;

		if(!memb.closed)
		{
			memb.closed = true;
			removeRef(t, (cast(MemblockConduit)memb.stream).mMB);
		}

		return 0;
	}

	uword constructor(CrocThread* t)
	{
		auto memb = OutStreamObj.getThis(t);

		if(memb.stream !is null)
			throwStdException(t, "ValueException", "Attempting to call constructor on an already-initialized MemOutStream");

		checkParam(t, 1, CrocValue.Type.Memblock);

		pushNull(t);
		dup(t);
		pushNativeObj(t, new MemblockConduit(getVM(t), createRef(t, 1)));
		pushBool(t, true);
		superCall(t, -4, "constructor", 0);

		return 0;
	}
}

struct MemInoutStreamObj
{
static:
	alias InoutStreamObj.Members Members;

	void init(CrocThread* t)
	{
		CreateClass(t, "MemInoutStream", "InoutStream", (CreateClass* c)
		{
			c.method("constructor", &constructor);
		});

		newFunction(t, &finalizer, "MemInoutStream.finalizer");
		setFinalizer(t, -2);

		newGlobal(t, "MemInoutStream");
	}

	uword finalizer(CrocThread* t)
	{
		auto memb = cast(Members*)getExtraBytes(t, 0).ptr;

		if(!memb.closed)
		{
			memb.closed = true;
			removeRef(t, (cast(MemblockConduit)memb.stream).mMB);
		}

		return 0;
	}

	uword constructor(CrocThread* t)
	{
		auto memb = InoutStreamObj.getThis(t);

		if(memb.stream !is null)
			throwStdException(t, "ValueException", "Attempting to call constructor on an already-initialized MemInoutStream");

		checkParam(t, 1, CrocValue.Type.Memblock);

		pushNull(t);
		dup(t);
		pushNativeObj(t, new MemblockConduit(getVM(t), createRef(t, 1)));
		pushBool(t, true);
		superCall(t, -4, "constructor", 0);

		return 0;
	}
}

template ReadFuncs(bool isInout)
{
	void readExact(CrocThread* t, Members* memb, void* dest, uword size)
	{
		while(size > 0)
		{
			auto numRead = safeCode(t, "exceptions.IOException", memb.stream.read(dest[0 .. size]));

			if(numRead == IOStream.Eof)
				throwStdException(t, "IOException", "End-of-flow encountered while reading");

			size -= numRead;
			dest += numRead;
		}
	}

	uword readAtMost(CrocThread* t, Members* memb, void* dest, uword size)
	{
		auto initial = size;

		while(size > 0)
		{
			auto numRead = safeCode(t, "exceptions.IOException", memb.stream.read(dest[0 .. size]));

			if(numRead == IOStream.Eof)
				break;
			else if(numRead < size)
			{
				size -= numRead;
				break;
			}

			size -= numRead;
			dest += numRead;
		}

		return initial - size;
	}

	uword readVal(T)(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);
		T val = void;

		readExact(t, memb, &val, T.sizeof);

		static if(isIntegerType!(T))
			pushInt(t, cast(crocint)val);
		else static if(isRealType!(T))
			pushFloat(t, val);
		else static if(isCharType!(T))
			pushChar(t, val);
		else
			static assert(false);

		return 1;
	}

	uword readString(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);

		uword length = void;
		readExact(t, memb, &length, length.sizeof);

		auto dat = t.vm.alloc.allocArray!(char)(length);

		scope(exit)
			t.vm.alloc.freeArray(dat);

		readExact(t, memb, dat.ptr, dat.length * char.sizeof);
		pushString(t, dat);
		return 1;
	}

	uword readln(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);
		auto ret = safeCode(t, "exceptions.IOException", memb.lines.next());

		if(ret.ptr is null)
			throwStdException(t, "IOException", "Stream has no more data.");

		pushString(t, ret);
		return 1;
	}

	uword readChars(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto num = checkIntParam(t, 1);

		if(num < 0 || num > uword.max)
			throwStdException(t, "RangeException", "Invalid number of characters ({})", num);

		static if(isInout) checkDirty(t, memb);

		auto dat = t.vm.alloc.allocArray!(char)(cast(uword)num);

		scope(exit)
			t.vm.alloc.freeArray(dat);

		readExact(t, memb, dat.ptr, dat.length * char.sizeof);
		pushString(t, dat);
		return 1;
	}

	uword readMemblock(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);
		checkAnyParam(t, 1);

		crocint size = void;
		CrocMemblock* mb = void;

		if(isInt(t, 1))
		{
			size = getInt(t, 1);

			if(size < 0 || size > uword.max)
				throwStdException(t, "RangeException", "Invalid size: {}", size);

			newMemblock(t, cast(uword)size);
			mb = getMemblock(t, -1);
		}
		else if(isMemblock(t, 1))
		{
			mb = getMemblock(t, 1);
			size = optIntParam(t, 2, mb.data.length);

			if(size < 0 || size > uword.max)
				throwStdException(t, "RangeException", "Invalid size: {}", size);

			if(size != mb.data.length)
				lenai(t, 1, size);

			dup(t, 1);
		}
		else
			paramTypeError(t, 1, "int|memblock");

		readExact(t, memb, mb.data.ptr, cast(uword)size);
		return 1;
	}

	uword rawRead(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);
		checkParam(t, 1, CrocValue.Type.Memblock);
		auto mb = getMemblock(t, 1);

		if(mb.data.length == 0)
			throwStdException(t, "ValueException", "Memblock cannot be 0 elements long");

		auto realSize = readAtMost(t, memb, mb.data.ptr, mb.data.length);
		pushInt(t, realSize);
		return 1;
	}

	uword iterator(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);
		auto index = checkIntParam(t, 1) + 1;
		auto line = safeCode(t, "exceptions.IOException", memb.lines.next());

		if(line.ptr is null)
			return 0;

		pushInt(t, index);
		pushString(t, line);
		return 2;
	}

	uword opApply(CrocThread* t)
	{
		checkInstParam(t, 0, isInout ? "InoutStream" : "InStream");
		getUpval(t, 0);
		dup(t, 0);
		pushInt(t, 0);
		return 3;
	}

	uword skip(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto dist_ = checkIntParam(t, 1);

		if(dist_ < 0 || dist_ > uword.max)
			throwStdException(t, "RangeException", "Invalid skip distance ({})", dist_);

		auto dist = cast(uword)dist_;

		static if(isInout) checkDirty(t, memb);

		// it's OK if this is shared - it's just a bit bucket
		static ubyte[1024] dummy;

		while(dist > 0)
		{
			uword numBytes = dist < dummy.length ? dist : dummy.length;
			readExact(t, memb, dummy.ptr, numBytes);
			dist -= numBytes;
		}

		return 0;
	}
}

template WriteFuncs(bool isInout)
{
	void writeExact(CrocThread* t, Members* memb, void* src, uword size)
	{
		while(size > 0)
		{
			auto numWritten = safeCode(t, "exceptions.IOException", memb.stream.write(src[0 .. size]));

			if(numWritten == IOStream.Eof)
				throwStdException(t, "IOException", "End-of-flow encountered while writing");

			size -= numWritten;
			src += numWritten;
		}
	}

	uword writeVal(T)(CrocThread* t)
	{
		auto memb = getOpenThis(t);

		static if(isIntegerType!(T))
			T val = cast(T)checkIntParam(t, 1);
		else static if(isRealType!(T))
			T val = cast(T)checkFloatParam(t, 1);
		else static if(isCharType!(T))
			T val = cast(T)checkCharParam(t, 1);
		else
			static assert(false);

		writeExact(t, memb, &val, val.sizeof);
		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword writeString(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto str = checkStringParam(t, 1);

		auto len = str.length;
		writeExact(t, memb, &len, len.sizeof);
		writeExact(t, memb, str.ptr, str.length * char.sizeof);

		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword write(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto p = memb.print;
		auto numParams = stackSize(t) - 1;

		for(uword i = 1; i <= numParams; i++)
		{
			pushToString(t, i);
			safeCode(t, "exceptions.IOException", p.print(getString(t, -1)));
			pop(t);
		}

		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword writeln(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto p = memb.print;
		auto numParams = stackSize(t) - 1;

		for(uword i = 1; i <= numParams; i++)
		{
			pushToString(t, i);
			safeCode(t, "exceptions.IOException", p.print(getString(t, -1)));
			pop(t);
		}

		safeCode(t, "exceptions.IOException", p.newline());
		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword writef(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto p = memb.print;
		auto numParams = stackSize(t) - 1;

		safeCode(t, "exceptions.IOException", formatImpl(t, numParams, delegate uint(char[] s)
		{
			p.print(s);
			return s.length;
		}));

		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword writefln(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto p = memb.print;
		auto numParams = stackSize(t) - 1;

		safeCode(t, "exceptions.IOException", formatImpl(t, numParams, delegate uint(char[] s)
		{
			p.print(s);
			return s.length;
		}));

		safeCode(t, "exceptions.IOException", p.newline());
		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword writeChars(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto str = checkStringParam(t, 1);
		writeExact(t, memb, str.ptr, str.length * char.sizeof);
		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword writeMemblock(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		checkParam(t, 1, CrocValue.Type.Memblock);
		auto mb = getMemblock(t, 1);
		auto lo = optIntParam(t, 2, 0);
		auto hi = optIntParam(t, 3, mb.data.length);

		if(lo < 0)
			lo += mb.data.length;

		if(hi < 0)
			hi += mb.data.length;

		if(lo < 0 || lo > hi || hi > mb.data.length)
			throwStdException(t, "BoundsException", "Invalid indices: {} .. {} (memblock length: {})", lo, hi, mb.data.length);

		writeExact(t, memb, mb.data.ptr + cast(uword)lo, cast(uword)(hi - lo));
		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword flush(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		safeCode(t, "exceptions.IOException", memb.stream.flush());
		//safeCode(t, "exceptions.IOException", memb.stream.clear());
		static if(isInout) memb.dirty = false;
		dup(t, 0);
		return 1;
	}

	uword copy(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		checkInstParam(t, 1);

		InputStream stream;
		pushGlobal(t, "InStream");

		if(as(t, 1, -1))
		{
			pop(t);
			stream = getMembers!(InStreamObj.Members)(t, 1).stream;
		}
		else
		{
			pop(t);
			pushGlobal(t, "InoutStream");

			if(as(t, 1, -1))
			{
				pop(t);
				stream = getMembers!(InoutStreamObj.Members)(t, 1).stream;
			}
			else
				paramTypeError(t, 1, "InStream|InoutStream");
		}

		safeCode(t, "exceptions.IOException", memb.stream.copy(stream));
		static if(isInout) memb.dirty = true;
		dup(t, 0);
		return 1;
	}

	uword flushOnNL(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		safeCode(t, "exceptions.IOException", memb.print.flush = checkBoolParam(t, 1));
		return 0;
	}
}

template CommonFuncs(bool isInout, bool isOut)
{
	uword seek(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);
		auto pos = checkIntParam(t, 1);
		auto whence = checkCharParam(t, 2);

		if(whence == 'b')
			safeCode(t, "exceptions.IOException", memb.stream.seek(pos, IOStream.Anchor.Begin));
		else if(whence == 'c')
			safeCode(t, "exceptions.IOException", memb.stream.seek(pos, IOStream.Anchor.Current));
		else if(whence == 'e')
			safeCode(t, "exceptions.IOException", memb.stream.seek(pos, IOStream.Anchor.End));
		else
			throwStdException(t, "ValueException", "Invalid seek type '{}'", whence);

		dup(t, 0);
		return 1;
	}

	uword position(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		auto numParams = stackSize(t) - 1;

		if(numParams == 0)
		{
			pushInt(t, safeCode(t, "exceptions.IOException", cast(crocint)memb.stream.seek(0, IOStream.Anchor.Current)));
			return 1;
		}
		else
		{
			static if(isInout) checkDirty(t, memb);
			safeCode(t, "exceptions.IOException", memb.stream.seek(checkIntParam(t, 1), IOStream.Anchor.Begin));
			return 0;
		}
	}

	uword size(CrocThread* t)
	{
		auto memb = getOpenThis(t);
		static if(isInout) checkDirty(t, memb);
		auto pos = safeCode(t, "exceptions.IOException", memb.stream.seek(0, IOStream.Anchor.Current));
		auto ret = safeCode(t, "exceptions.IOException", memb.stream.seek(0, IOStream.Anchor.End));
		safeCode(t, "exceptions.IOException", memb.stream.seek(pos, IOStream.Anchor.Begin));
		pushInt(t, cast(crocint)ret);
		return 1;
	}

	uword close(CrocThread* t)
	{
		auto memb = getOpenThis(t);

		if(!memb.closable)
			throwStdException(t, "ValueException", "Attempting to close an unclosable stream");

		memb.closed = true;
		static if(isInout || isOut) safeCode(t, "exceptions.IOException", memb.stream.flush());
		safeCode(t, "exceptions.IOException", memb.stream.close());
		return 0;
	}

	uword isOpen(CrocThread* t)
	{
		pushBool(t, !getThis(t).closed);
		return 1;
	}
}

const char[] WriteFuncDefs =
`c.method("writeByte",     1, &writeVal!(byte));
c.method("writeUByte",    1, &writeVal!(ubyte));
c.method("writeShort",    1, &writeVal!(short));
c.method("writeUShort",   1, &writeVal!(ushort));
c.method("writeInt",      1, &writeVal!(int));
c.method("writeUInt",     1, &writeVal!(uint));
c.method("writeLong",     1, &writeVal!(long));
c.method("writeULong",    1, &writeVal!(ulong));
c.method("writeFloat",    1, &writeVal!(float));
c.method("writeDouble",   1, &writeVal!(double));
c.method("writeChar",     1, &writeVal!(char));
c.method("writeWChar",    1, &writeVal!(wchar));
c.method("writeDChar",    1, &writeVal!(dchar));
c.method("writeString",   1, &writeString);
c.method("write",            &write);
c.method("writeln",          &writeln);
c.method("writef",           &writef);
c.method("writefln",         &writefln);
c.method("writeChars",    1, &writeChars);
c.method("writeMemblock", 3, &writeMemblock);
c.method("flush",         0, &flush);
c.method("copy",          1, &copy);
c.method("flushOnNL",     1, &flushOnNL);`;

const char[] ReadFuncDefs =
`c.method("readByte",     0, &readVal!(byte));
c.method("readUByte",    0, &readVal!(ubyte));
c.method("readShort",    0, &readVal!(short));
c.method("readUShort",   0, &readVal!(ushort));
c.method("readInt",      0, &readVal!(int));
c.method("readUInt",     0, &readVal!(uint));
c.method("readLong",     0, &readVal!(long));
c.method("readULong",    0, &readVal!(ulong));
c.method("readFloat",    0, &readVal!(float));
c.method("readDouble",   0, &readVal!(double));
c.method("readChar",     0, &readVal!(char));
c.method("readWChar",    0, &readVal!(wchar));
c.method("readDChar",    0, &readVal!(dchar));
c.method("readString",   0, &readString);
c.method("readln",       0, &readln);
c.method("readChars",    1, &readChars);
c.method("readMemblock", 2, &readMemblock);
c.method("rawRead",      2, &rawRead);
c.method("skip",         1, &skip);
	newFunction(t, &iterator, "InStream.iterator");
c.method("opApply", 1, &opApply, 1);`;

const char[] CommonFuncDefs =
`c.method("seek",         2, &seek);
c.method("position",     1, &position);
c.method("size",         0, &size);
c.method("close",        0, &close);
c.method("isOpen",       0, &isOpen);`;