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

module minid.iolib;

import tango.io.Buffer;
import tango.io.Console;
import tango.io.device.Conduit;
import tango.io.device.FileConduit;
import tango.io.File;
import tango.io.FilePath;
import tango.io.FileSystem;
import tango.io.model.IConduit;
import tango.io.Print;
import tango.io.protocol.Reader;
import tango.io.protocol.Writer;
import tango.io.UnicodeFile;
import tango.text.convert.Layout;
import tango.text.stream.LineIterator;
import tango.util.PathUtil;
import Utf = tango.text.convert.Utf;

import minid.ex;
import minid.interpreter;
import minid.misc;
import minid.types;
import minid.utils;
import minid.vector;

struct IOLib
{
static:
	private const FileConduit.Style DefaultFileStyle;

	static this()
	{
		DefaultFileStyle = FileConduit.Style
		(
			FileConduit.Access.Read,
			FileConduit.ReadExisting.open,
			FileConduit.Share.ReadWrite,
			FileConduit.ReadExisting.cache
		);
	}

	enum FileMode : mdint
	{
		In = 1,
		Out = 2,
		New = 4,
		Append = 8,
		OutNew = Out | New
	}

	public void init(MDThread* t)
	{
		pushGlobal(t, "modules");
		field(t, -1, "customLoaders");

		newFunction(t, function uword(MDThread* t, uword numParams)
		{
			InputStreamObj.init(t);
			OutputStreamObj.init(t);
			StreamObj.init(t);

				pushGlobal(t, "InputStream");
				pushNull(t);
				pushNativeObj(t, cast(Object)Cin.stream);
				methodCall(t, -3, "clone", 1);
			newGlobal(t, "stdin");

				pushGlobal(t, "OutputStream");
				pushNull(t);
				pushNativeObj(t, cast(Object)Cout.stream);
				methodCall(t, -3, "clone", 1);
			newGlobal(t, "stdout");

				pushGlobal(t, "OutputStream");
				pushNull(t);
				pushNativeObj(t, cast(Object)Cerr.stream);
				methodCall(t, -3, "clone", 1);
			newGlobal(t, "stderr");

			newTable(t, 5);
				pushString(t, "In");     pushInt(t, FileMode.In);     fielda(t, -3);
				pushString(t, "Out");    pushInt(t, FileMode.Out);    fielda(t, -3);
				pushString(t, "New");    pushInt(t, FileMode.New);    fielda(t, -3);
				pushString(t, "Append"); pushInt(t, FileMode.Append); fielda(t, -3);
				pushString(t, "OutNew"); pushInt(t, FileMode.OutNew); fielda(t, -3);
			newGlobal(t, "FileMode");

			newFunction(t, &File, "File");             newGlobal(t, "File");
			newFunction(t, &rename, "rename");         newGlobal(t, "rename");
			newFunction(t, &remove, "remove");         newGlobal(t, "remove");
			newFunction(t, &copy, "copy");             newGlobal(t, "copy");
			newFunction(t, &size, "size");             newGlobal(t, "size");
			newFunction(t, &exists, "exists");         newGlobal(t, "exists");
			newFunction(t, &isFile, "isFile");         newGlobal(t, "isFile");
			newFunction(t, &isDir, "isDir");           newGlobal(t, "isDir");
			newFunction(t, &currentDir, "currentDir"); newGlobal(t, "currentDir");
			newFunction(t, &changeDir, "changeDir");   newGlobal(t, "changeDir");
			newFunction(t, &makeDir, "makeDir");       newGlobal(t, "makeDir");
			newFunction(t, &removeDir, "removeDir");   newGlobal(t, "removeDir");
			newFunction(t, &listFiles, "listFiles");   newGlobal(t, "listFiles");
			newFunction(t, &listDirs, "listDirs");     newGlobal(t, "listDirs");
			newFunction(t, &readFile, "readFile");     newGlobal(t, "readFile");
			newFunction(t, &writeFile, "writeFile");   newGlobal(t, "writeFile");

			return 0;
		}, "io");

		fielda(t, -2, "io");
		importModule(t, "io");
		pop(t, 3);
	}

	uword rename(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		safeCode(t, fp.rename(checkStringParam(t, 2)));
		return 0;
	}

	uword remove(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		safeCode(t, fp.remove());
		return 0;
	}

	uword copy(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 2));
		safeCode(t, fp.copy(checkStringParam(t, 1)));
		return 0;
	}

	uword size(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		pushInt(t, cast(mdint)safeCode(t, fp.fileSize()));
		return 1;
	}

	uword exists(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		pushBool(t, fp.exists());
		return 1;
	}

	uword isFile(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		pushBool(t, safeCode(t, !fp.isFolder()));
		return 1;
	}

	uword isDir(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		pushBool(t, safeCode(t, !fp.isFolder()));
		return 1;
	}

	uword currentDir(MDThread* t, uword numParams)
	{
		pushString(t, safeCode(t, FileSystem.getDirectory()));
		return 1;
	}

	uword changeDir(MDThread* t, uword numParams)
	{
		safeCode(t, FileSystem.setDirectory(checkStringParam(t, 1)));
		return 0;
	}

	uword makeDir(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));

		if(!fp.isAbsolute())
			fp.prepend(FileSystem.getDirectory());

		safeCode(t, fp.create());
		return 0;
	}

	uword removeDir(MDThread* t, uword numParams)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		safeCode(t, fp.remove());
		return 0;
	}
	
	uword listImpl(MDThread* t, uword numParams, bool isFolder)
	{
		scope fp = new FilePath(checkStringParam(t, 1));
		auto listing = newArray(t, 0);

		if(numParams == 1)
		{
			safeCode(t,
			{
				foreach(ref info; fp)
				{
					if(info.folder is isFolder)
					{
						pushString(t, info.path);
						pushString(t, info.name);
						cat(t, 2);
						cateq(t, listing, 1);
					}
				}
			}());
		}
		else
		{
			auto filter = checkStringParam(t, 2);

			safeCode(t,
			{
				foreach(ref info; fp)
				{
					if(info.folder is isFolder)
					{
						pushString(t, info.path);
						pushString(t, info.name);
						cat(t, 2);
						auto fullName = getString(t, -1);
						
						if(patternMatch(fullName, filter))
							cateq(t, listing, 1);
						else
							pop(t);
					}
				}
			}());
		}

		return 1;
	}

	uword listFiles(MDThread* t, uword numParams)
	{
		return listImpl(t, numParams, false);
	}

	uword listDirs(MDThread* t, uword numParams)
	{
		return listImpl(t, numParams, true);
	}

	uword readFile(MDThread* t, uword numParams)
	{
		auto name = checkStringParam(t, 1);

		if(numParams == 1 || checkBoolParam(t, 2) == false)
		{
			safeCode(t,
			{
				scope file = new UnicodeFile!(char)(name, Encoding.Unknown);
				pushString(t, file.read());
			}());
		}
		else
		{
			safeCode(t,
			{
				scope file = new .File(name);
				auto data = cast(ubyte[])file.read();

				scope(exit)
					delete data;

				foreach(ref c; data)
					if(c > 0x7f)
						c = '?';

				pushString(t, cast(char[])data);
			}());
		}

		return 1;
	}

	uword writeFile(MDThread* t, uword numParams)
	{
		auto name = checkStringParam(t, 1);
		auto data = checkStringParam(t, 2);

		safeCode(t,
		{
			scope file = new UnicodeFile!(char)(name, Encoding.UTF_8N);
			file.write(data);
		}());

		return 0;
	}

	uword File(MDThread* t, uword numParams)
	{
		FileConduit.Style parseFileMode(mdint mode)
		{
			auto s = DefaultFileStyle;

			s.access = FileConduit.Access.Read;

			if(mode & FileMode.Out)
				s.access |= FileConduit.Access.Write;

			s.open = cast(FileConduit.Open)0;

			if(mode & FileMode.New)
				s.open |= FileConduit.Open.Create;
			else
			{
				if(mode & FileMode.Append)
					s.open |= FileConduit.Open.Append;

				s.open |= FileConduit.Open.Exists;
			}

			return s;
		}

		safeCode(t,
		{
			auto name = checkStringParam(t, 1);

			auto f = numParams == 1
				? new FileConduit(name, DefaultFileStyle)
				: new FileConduit(name, parseFileMode(checkIntParam(t, 2)));
				
			pushGlobal(t, "Stream");
			pushNull(t);
			pushNativeObj(t, f);
			methodCall(t, -3, "clone", 1);
		}());

		return 1;
	}

	struct InputStreamObj
	{
	static:
		enum Fields
		{
			stream,
			reader,
			lines
		}

		struct Members
		{
			InputStream stream;
			IReader reader;
			LineIterator!(char) lines;
			IBuffer buf;
		}

		public void init(MDThread* t)
		{
			CreateObject(t, "InputStream", (CreateObject* o)
			{
				o.method("clone", &clone);
				o.method("readByte", &readVal!(ubyte));
				o.method("readShort", &readVal!(ushort));
				o.method("readInt", &readVal!(int));
				o.method("readLong", &readVal!(long));
				o.method("readFloat", &readVal!(float));
				o.method("readDouble", &readVal!(double));
				o.method("readChar", &readVal!(char));
				o.method("readWChar", &readVal!(wchar));
				o.method("readDChar", &readVal!(dchar));
				o.method("readString", &readString);
				o.method("readln", &readln);
				o.method("readChars", &readChars);
				o.method("readVector", &readVector);

					newFunction(t, &iterator, "InputStream.iterator");
				o.method("opApply", &opApply, 1);
			});

			newGlobal(t, "InputStream");
		}
		
		private Members* getThis(MDThread* t)
		{
			return checkObjParam!(Members)(t, 0, "InputStream");
		}

		public uword clone(MDThread* t, uword numParams)
		{
			checkParam(t, 1, MDValue.Type.NativeObj);
			auto input = cast(InputStream)getNativeObj(t, 1);

			if(input is null)
				throwException(t, "instances of InputStream may only be created using instances of the Tango InputStream");
				
			pushGlobal(t, "InputStream");
			auto ret = newObject(t, -1, null, Fields.max + 1, Members.sizeof);
			auto memb = cast(Members*)getExtraBytes(t, ret).ptr;

			memb.buf = Buffer.share(input);
			memb.stream = memb.buf;
			memb.reader = new Reader(memb.buf);
			memb.lines = new LineIterator!(char)(memb.buf);

			pushNativeObj(t, cast(Object)memb.stream); setExtraVal(t, ret, Fields.stream);
			pushNativeObj(t, memb.reader);             setExtraVal(t, ret, Fields.reader);
			pushNativeObj(t, memb.lines);              setExtraVal(t, ret, Fields.lines);

			return 1;
		}

		public uword readVal(T)(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);
			T val = void;
			safeCode(t, memb.reader.get(val));

			static if(isIntType!(T))
				pushInt(t, val);
			else static if(isFloatType!(T))
				pushFloat(t, val);
			else static if(isCharType!(T))
				pushChar(t, val);
			else
				static assert(false);

			return 1;
		}

		public uword readString(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);

			safeCode(t,
			{
				uword length = void;
				memb.reader.get(length);

				auto dat = t.vm.alloc.allocArray!(char)(length);

				scope(exit)
					t.vm.alloc.freeArray(dat);

				memb.buf.readExact(dat.ptr, length * char.sizeof);
				pushString(t, dat);
			}());

			return 1;
		}

		public uword readln(MDThread* t, uword numParams)
		{
			auto ret = safeCode(t, getThis(t).lines.next());

			if(ret.ptr is null)
				throwException(t, "Stream has no more data.");

			pushString(t, ret);
			return 1;
		}

		public uword readChars(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);
			auto num = checkIntParam(t, 1);

			if(num < 0 || num > uword.max)
				throwException(t, "Invalid number of characters ({})", num);

			safeCode(t,
			{
				auto dat = t.vm.alloc.allocArray!(char)(cast(uword)num);

				scope(exit)
					t.vm.alloc.freeArray(dat);

				memb.buf.readExact(dat.ptr, cast(uword)num * char.sizeof);
				pushString(t, dat);
			}());

			return 1;
		}

		public uword readVector(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);
			checkAnyParam(t, 1);

			mdint size = void;
			VectorObj.Members* vecMemb = void;

			if(isString(t, 1))
			{
				auto type = getString(t, 1);
				size = checkIntParam(t, 2);

				pushGlobal(t, "Vector");
				pushNull(t);
				pushString(t, type);
				pushInt(t, size);
				methodCall(t, -4, "clone", 1);

				vecMemb = getMembers!(VectorObj.Members)(t, -1);
			}
			else
			{
				pushGlobal(t, "Vector");

				if(!strictlyAs(t, 1, -1))
					paramTypeError(t, 1, "object Vector");

				vecMemb = getMembers!(VectorObj.Members)(t, -1);
				size = optIntParam(t, 2, vecMemb.length);

				if(size != vecMemb.length)
				{
					dup(t, 1);
					pushNull(t);
					pushInt(t, size);
					methodCall(t, -3, "opLengthAssign", 0);
				}

				dup(t, 1);
			}

			memb.buf.readExact(vecMemb.data, cast(uword)size * vecMemb.type.itemSize);

			return 1;
		}

		private uword iterator(MDThread* t, uword numParams)
		{
			auto index = checkIntParam(t, 1) + 1;
			auto line = safeCode(t, getThis(t).lines.next());

			if(line.ptr is null)
				return 0;

			pushInt(t, index);
			pushString(t, line);
			return 2;
		}

		public uword opApply(MDThread* t, uword numParams)
		{
			checkObjParam(t, 0, "InputStream");
			getUpval(t, 0);
			dup(t, 0);
			pushInt(t, 0);
			return 3;
		}
	}

	struct OutputStreamObj
	{
	static:
		enum Fields
		{
			stream,
			writer,
			print
		}
		
		struct Members
		{
			OutputStream stream;
			IWriter writer;
			Print!(char) print;
			IBuffer buf;
		}

		public void init(MDThread* t)
		{
			CreateObject(t, "OutputStream", (CreateObject* o)
			{
					newFunction(t, &finalizer, "OutputStream.finalizer");
				o.method("clone",       &clone, 1);

				o.method("writeByte",   &writeVal!(ubyte));
				o.method("writeShort",  &writeVal!(ushort));
				o.method("writeInt",    &writeVal!(int));
				o.method("writeFloat",  &writeVal!(float));
				o.method("writeDouble", &writeVal!(double));
				o.method("writeChar",   &writeVal!(char));
				o.method("writeWChar",  &writeVal!(wchar));
				o.method("writeDChar",  &writeVal!(dchar));
				o.method("writeString", &writeString);
				o.method("write",       &write);
				o.method("writeln",     &writeln);
				o.method("writef",      &writef);
				o.method("writefln",    &writefln);
				o.method("writeChars",  &writeChars);
				o.method("writeJSON",   &writeJSON);
				o.method("flush",       &flush);
				o.method("copy",        &copy);
			});

			newGlobal(t, "OutputStream");
		}
		
		uword finalizer(MDThread* t, uword numParams)
		{
			auto memb = cast(Members*)getExtraBytes(t, 0).ptr;
			
			if(memb.stream !is null)
			{
				memb.stream.flush();
				memb.stream = null;
			}

			return 0;
		}
		
		Members* getThis(MDThread* t)
		{
			return checkObjParam!(Members)(t, 0, "OutputStream");
		}

		public uword clone(MDThread* t, uword numParams)
		{
			checkParam(t, 1, MDValue.Type.NativeObj);
			auto output = cast(OutputStream)getNativeObj(t, 1);

			if(output is null)
				throwException(t, "instances of OutputStream may only be created using instances of the Tango OutputStream");

			pushGlobal(t, "OutputStream");
			auto ret = newObject(t, -1, null, Fields.max + 1, Members.sizeof);
			auto memb = cast(Members*)getExtraBytes(t, ret).ptr;

			memb.buf = Buffer.share(output);
			memb.stream = memb.buf;
			memb.writer = new Writer(memb.buf);
			memb.print = new Print!(char)(t.vm.formatter, memb.buf);

			pushNativeObj(t, cast(Object)memb.stream); setExtraVal(t, ret, Fields.stream);
			pushNativeObj(t, memb.writer);             setExtraVal(t, ret, Fields.writer);
			pushNativeObj(t, memb.print);              setExtraVal(t, ret, Fields.print);
			
			getUpval(t, 0);
			setFinalizer(t, ret);

			return 1;
		}

		public uword writeVal(T)(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);

			static if(isIntType!(T))
				T val = cast(T)checkIntParam(t, 1);
			else static if(isFloatType!(T))
				T val = cast(T)checkFloatParam(t, 1);
			else static if(isCharType!(T))
				T val = cast(T)checkCharParam(t, 1);
			else
				static assert(false);

			safeCode(t, memb.writer.put(val));
			dup(t, 0);
			return 1;
		}

		public uword writeString(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);
			auto str = checkStringParam(t, 1);

			safeCode(t,
			{
				memb.writer.put(str.length);
				memb.buf.append(str.ptr, str.length * char.sizeof);
			}());

			dup(t, 0);
			return 1;
		}

		public uword write(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);

			for(uword i = 1; i <= numParams; i++)
			{
				pushToString(t, i);
				safeCode(t, memb.print.print(getString(t, -1)));
				pop(t);
			}

			dup(t, 0);
			return 1;
		}

		public uword writeln(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);

			for(uword i = 1; i <= numParams; i++)
			{
				pushToString(t, i);
				safeCode(t, memb.print.print(getString(t, -1)));
				pop(t);
			}

			safeCode(t, memb.print.newline());
			dup(t, 0);
			return 1;
		}

		public uword writef(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);

			safeCode(t, formatImpl(t, numParams, (char[] s)
			{
				memb.print.print(s);
				return s.length;
			}));

			dup(t, 0);
			return 1;
		}

		public uword writefln(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);

			safeCode(t, formatImpl(t, numParams, (char[] s)
			{
				memb.print.print(s);
				return s.length;
			}));

			safeCode(t, memb.print.newline());
			dup(t, 0);
			return 1;
		}

		public uword writeChars(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);
			auto str = checkStringParam(t, 1);
			safeCode(t, memb.buf.append(str.ptr, str.length * char.sizeof));
			dup(t, 0);
			return 1;
		}

		public uword writeJSON(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);
			checkAnyParam(t, 1);
			auto pretty = optBoolParam(t, 2, false);
			toJSONImpl(t, 1, pretty, memb.print);
			dup(t, 0);
			return 1;
		}

		public uword flush(MDThread* t, uword numParams)
		{
			safeCode(t, getThis(t).buf.flush());
			dup(t, 0);
			return 1;
		}

		public uword copy(MDThread* t, uword numParams)
		{
			auto memb = getThis(t);
			checkObjParam(t, 1);

			InputStream stream;
			pushGlobal(t, "InputStream");

			if(strictlyAs(t, 1, -1))
			{
				pop(t);
				stream = (cast(InputStreamObj.Members*)getExtraBytes(t, 1).ptr).stream;
			}
			else
			{
				pop(t);
				pushGlobal(t, "Stream");

				if(strictlyAs(t, 1, -1))
				{
					pop(t);
					getExtraVal(t, 1, StreamObj.Members.input);
					getExtraVal(t, -1, InputStreamObj.Members.input);
					stream = cast(InputStream)cast(void*)getNativeObj(t, -1);
					pop(t, 2);
				}
				else
				{
					pushTypeString(t, 1);
					throwException(t, "object must be either an InputStream or a Stream, not a '{}'", getString(t, -1));
				}
			}
			
			safeCode(t, o.copy(stream));
			dup(t, 0);
			return 1;
		}
	}

	struct StreamObj
	{
	static:
		enum Members
		{
			conduit,
			input,
			output,
			seeker	
		}

		public void init(MDThread* t)
		{
			CreateObject(t, "Stream", (CreateObject* o)
			{
				o.method("clone", &clone);
				o.method("readByte", &readVal!(ubyte));
				o.method("readShort", &readVal!(ushort));
				o.method("readInt", &readVal!(int));
				o.method("readFloat", &readVal!(float));
				o.method("readDouble", &readVal!(double));
				o.method("readChar", &readVal!(char));
				o.method("readWChar", &readVal!(wchar));
				o.method("readDChar", &readVal!(dchar));
				o.method("readString", &readString);
				o.method("readln", &readln);
				o.method("readChars", &readChars);
				o.method("opApply", &opApply);

				o.method("writeByte", &writeVal!(ubyte));
				o.method("writeShort", &writeVal!(ushort));
				o.method("writeInt", &writeVal!(int));
				o.method("writeFloat", &writeVal!(float));
				o.method("writeDouble", &writeVal!(double));
				o.method("writeChar", &writeVal!(char));
				o.method("writeWChar", &writeVal!(wchar));
				o.method("writeDChar", &writeVal!(dchar));
				o.method("writeString", &writeString);
				o.method("write", &write);
				o.method("writeln", &writeln);
				o.method("writef", &writef);
				o.method("writefln", &writefln);
				o.method("writeChars", &writeChars);
				o.method("writeJSON", &writeJSON);
				o.method("flush", &flush);
				o.method("copy", &copy);

				o.method("seek", &seek);
				o.method("position", &position);
				o.method("size", &size);
				o.method("close", &close);
				o.method("isOpen", &isOpen);

				o.method("input", &input);
				o.method("output", &output);
			});
			
			newGlobal(t, "Stream");
		}
		
		public uword clone(MDThread* t, uword numParams)
		{
			checkParam(t, 1, MDValue.Type.NativeObj);
			auto conduit = cast(IConduit)getNativeObj(t, 1);

			if(conduit is null)
				throwException(t, "instances of Stream may only be created using instances of Tango's IConduit");

			auto seeker = cast(IConduit.Seek)conduit;

			pushGlobal(t, "Stream");
			auto ret = newObject(t, -1, null, 4);

			pushNativeObj(t, cast(Object)conduit); setExtraVal(t, ret, Members.conduit);

			if(seeker is null)
				pushNull(t);
			else
				pushNativeObj(t, cast(Object)seeker);
				
			setExtraVal(t, ret, Members.seeker);

				pushGlobal(t, "InputStream");
				pushNull(t);
				pushNativeObj(t, cast(Object)conduit);
				methodCall(t, -3, "clone", 1);
			setExtraVal(t, ret, Members.input);

				pushGlobal(t, "OutputStream");
				pushNull(t);
				pushNativeObj(t, cast(Object)conduit);
				methodCall(t, -3, "clone", 1);
			setExtraVal(t, ret, Members.output);

			return 1;
		}
		
		word pushInput(MDThread* t)
		{
			checkObjParam(t, 0, "Stream");
			return getExtraVal(t, 0, Members.input);
		}

		word pushOutput(MDThread* t)
		{
			checkObjParam(t, 0, "Stream");
			return getExtraVal(t, 0, Members.output);
		}

		IConduit.Seek getSeeker(MDThread* t)
		{
			checkObjParam(t, 0, "Stream");
			getExtraVal(t, 0, Members.seeker);
			
			if(isNull(t, -1))
				throwException(t, "Stream is not seekable.");

			auto ret = cast(IConduit.Seek)cast(void*)getNativeObj(t, -1);
			pop(t);
			return ret;
		}

		IConduit getConduit(MDThread* t)
		{
			checkObjParam(t, 0, "Stream");
			getExtraVal(t, 0, Members.conduit);
			auto ret = cast(IConduit)cast(void*)getNativeObj(t, -1);
			pop(t);
			return ret;
		}

		public uword readVal(T)(MDThread* t, uword numParams)
		{
			pushInput(t);
			swap(t, 0);
			pop(t);
			return InputStreamObj.readVal!(T)(t, numParams);
		}

		public uword readString(MDThread* t, uword numParams)
		{
			pushInput(t);
			swap(t, 0);
			pop(t);
			return InputStreamObj.readString(t, numParams);
		}

		public uword readln(MDThread* t, uword numParams)
		{
			pushInput(t);
			swap(t, 0);
			pop(t);
			return InputStreamObj.readln(t, numParams);
		}

		public uword readChars(MDThread* t, uword numParams)
		{
			pushInput(t);
			swap(t, 0);
			pop(t);
			return InputStreamObj.readChars(t, numParams);
		}

		public uword opApply(MDThread* t, uword numParams)
		{
			pushInput(t);
			pushNull(t);
			return methodCall(t, -2, "opApply", -1);
		}

		public uword writeVal(T)(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.writeVal!(T)(t, numParams);
			pop(t);
			return 1;
		}

		public uword writeString(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.writeString(t, numParams);
			pop(t);
			return 1;
		}

		public uword write(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.write(t, numParams);
			pop(t);
			return 1;
		}

		public uword writeln(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.writeln(t, numParams);
			pop(t);
			return 1;
		}

		public uword writef(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.writef(t, numParams);
			pop(t);
			return 1;
		}

		public uword writefln(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.writefln(t, numParams);
			pop(t);
			return 1;
		}

		public uword writeChars(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.writeChars(t, numParams);
			pop(t);
			return 1;
		}

		public uword writeJSON(MDThread* t, uword numParams)
		{
			checkAnyParam(t, 1);

			// Have to set up the stack so that OutputStream.writeJSON doesn't see 'this' on it
			if(numParams == 1)
				pushNull(t);

			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.writeJSON(t, numParams);
			pop(t);
			return 1;
		}

		public uword flush(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.flush(t, numParams);
			pop(t);
			return 1;
		}
		
		public uword copy(MDThread* t, uword numParams)
		{
			pushOutput(t);
			swap(t, 0);
			OutputStreamObj.copy(t, numParams);
			pop(t);
			return 1;
		}

		public uword seek(MDThread* t, uword numParams)
		{
			auto seeker = getSeeker(t);
			auto pos = checkIntParam(t, 1);
			auto whence = checkCharParam(t, 2);

			if(whence == 'b')
				safeCode(t, seeker.seek(pos, IConduit.Seek.Anchor.Begin));
			else if(whence == 'c')
				safeCode(t, seeker.seek(pos, IConduit.Seek.Anchor.Current));
			else if(whence == 'e')
				safeCode(t, seeker.seek(pos, IConduit.Seek.Anchor.End));
			else
				throwException(t, "Invalid seek type '{}'", whence);

			getExtraVal(t, 0, Members.input);
			getExtraVal(t, -1, InputStreamObj.Members.input);
			(cast(InputStream)cast(void*)getNativeObj(t, -1)).clear();

			return 0;
		}

		public uword position(MDThread* t, uword numParams)
		{
			auto seeker = getSeeker(t);

			if(numParams == 0)
			{
				pushInt(t, safeCode(t, cast(mdint)seeker.seek(0, IConduit.Seek.Anchor.Current)));
				return 1;
			}
			else
			{
				safeCode(t, seeker.seek(checkIntParam(t, 1), IConduit.Seek.Anchor.Begin));
				getExtraVal(t, 0, Members.input);
				getExtraVal(t, -1, InputStreamObj.Members.input);
				(cast(InputStream)cast(void*)getNativeObj(t, -1)).clear();
				return 0;
			}
		}

		public uword size(MDThread* t, uword numParams)
		{
			auto seeker = getSeeker(t);

			auto pos = seeker.seek(0, IConduit.Seek.Anchor.Current);
			auto ret = seeker.seek(0, IConduit.Seek.Anchor.End);
			seeker.seek(pos, IConduit.Seek.Anchor.Begin);

			pushInt(t, cast(mdint)ret);
			return 1;
		}

		public uword close(MDThread* t, uword numParams)
		{
			pushOutput(t);
			getExtraVal(t, -1, OutputStreamObj.Members.output);
			try (cast(OutputStream)cast(void*)getNativeObj(t, -1)).flush(); catch{}
			getConduit(t).close();
			return 0;
		}

		public uword isOpen(MDThread* t, uword numParams)
		{
			pushBool(t, getConduit(t).isAlive());
			return 1;
		}

		public uword input(MDThread* t, uword numParams)
		{
			checkObjParam(t, 0, "Stream");
			getExtraVal(t, 0, Members.input);
			return 1;
		}

		public uword output(MDThread* t, uword numParams)
		{
			checkObjParam(t, 0, "Stream");
			getExtraVal(t, 0, Members.output);
			return 1;
		}
	}
}