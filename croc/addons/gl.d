/******************************************************************************
A binding to OpenGL and glu through Derelict.

License:
Copyright (c) 2009 Jarrett Billingsley

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

module croc.addons.gl;

version(CrocAllAddons)
	version = CrocGlAddon;

version(CrocGlAddon)
{

import tango.stdc.stringz;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.util.exception;

import croc.api;

import croc.addons.gl_wrap;
import croc.addons.gl_ext;

template typeStringOf(_T)
{
	static if(is(realType!(_T) == byte))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.i8].name;
	else static if(is(realType!(_T) == ubyte))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.u8].name;
	else static if(is(realType!(_T) == short))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.i16].name;
	else static if(is(realType!(_T) == ushort))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.u16].name;
	else static if(is(realType!(_T) == int))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.i32].name;
	else static if(is(realType!(_T) == uint))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.u32].name;
	else static if(is(realType!(_T) == long))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.i64].name;
	else static if(is(realType!(_T) == ulong))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.u64].name;
	else static if(is(realType!(_T) == float))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.f32].name;
	else static if(is(realType!(_T) == double))
		const typeStringOf = CrocMemblock.typeStructs[CrocMemblock.TypeCode.f64].name;
	else
		static assert(false, "Don't know what type string corresponds to " ~ _T.stringof);
}

struct GlLib
{
static:
	void init(CrocThread* t)
	{
		makeModule(t, "gl", function uword(CrocThread* t)
		{
			CreateClass(t, "GLException", "exceptions.Exception", (CreateClass* c) {});
			newGlobal(t, "GLException");

			register(t, &load, "load");

			pushString(t, typeStringOf!(GLenum)); newGlobal(t, "GLenum");
			pushString(t, typeStringOf!(GLboolean)); newGlobal(t, "GLboolean");
			pushString(t, typeStringOf!(GLbitfield)); newGlobal(t, "GLbitfield");
			pushString(t, typeStringOf!(GLbyte)); newGlobal(t, "GLbyte");
			pushString(t, typeStringOf!(GLshort)); newGlobal(t, "GLshort");
			pushString(t, typeStringOf!(GLint)); newGlobal(t, "GLint");
			pushString(t, typeStringOf!(GLubyte)); newGlobal(t, "GLubyte");
			pushString(t, typeStringOf!(GLushort)); newGlobal(t, "GLushort");
			pushString(t, typeStringOf!(GLuint)); newGlobal(t, "GLuint");
			pushString(t, typeStringOf!(GLsizei)); newGlobal(t, "GLsizei");
			pushString(t, typeStringOf!(GLfloat)); newGlobal(t, "GLfloat");
			pushString(t, typeStringOf!(GLclampf)); newGlobal(t, "GLclampf");
			pushString(t, typeStringOf!(GLdouble)); newGlobal(t, "GLdouble");
			pushString(t, typeStringOf!(GLclampd)); newGlobal(t, "GLclampd");

			return 0;
		});

		pushBool(t, false);
		setRegistryVar(t, "gl.loaded");
	}

	uword load(CrocThread* t)
	{
		getRegistryVar(t, "gl.loaded");

		if(getBool(t, -1))
			return 0;

		pop(t);

		safeCode(t, "GLException",
		{
			GLVersion v;

			// this loads 1.0 and 1.1
			DerelictGL.load();
			DerelictGLU.load();

			try
				v = DerelictGL.availableVersion();
			catch(SharedLibProcLoadException e)
				v = DerelictGL.availableVersion();

			// Clever switch which falls through on each case to load all available funcs
			switch(v)
			{
				case GLVersion.Version21: loadGL21(t);
				case GLVersion.Version20: loadGL20(t);
				case GLVersion.Version15: loadGL15(t);
				case GLVersion.Version14: loadGL14(t);
				case GLVersion.Version13: loadGL13(t);
				case GLVersion.Version12: loadGL12(t);
				case GLVersion.Version11: loadGLBase(t); break;
				default:
					throwStdException(t, "Exception", "I have no idea what version of OpenGL you have");
			}

			DerelictGL.loadExtensions();
			loadExtensions(t);
		}());

		newFunction(t, &version_, "version");
		newGlobal(t, "version");

		pushBool(t, true);
		setRegistryVar(t, "gl.loaded");

		version(CrocGLCheckErrors)
		{
			pushBool(t, false);
			setRegistryVar(t, "gl.insideBeginEnd");
		}

		return 0;
	}

	uword version_(CrocThread* t)
	{
		pushString(t, safeCode(t, "GLException", DerelictGL.versionString(DerelictGL.availableVersion())));
		return 1;
	}

	uword crocgluErrorString(CrocThread* t)
	{
		auto str = gluErrorString(cast(uword)checkIntParam(t, 1));
		pushString(t, fromStringz(cast(char*)str));
		return 1;
	}

	uword crocgluGetString(CrocThread* t)
	{
		auto str = gluGetString(cast(uword)checkIntParam(t, 1));
		pushString(t, fromStringz(cast(char*)str));
		return 1;
	}

	uword crocglShaderSource(CrocThread* t)
	{
		auto shader = cast(GLuint)checkIntParam(t, 1);
		auto src = checkStringParam(t, 2);

		GLchar* str = src.ptr;
		GLint len = src.length;

		glShaderSource(shader, 1, &str, &len);
		
		version(CrocGLCheckErrors)
			checkError(t, "glShaderSource");

		return 0;
	}

	uword crocglMapBuffer(CrocThread* t)
	{
		auto target = cast(GLenum)checkIntParam(t, 1);
		auto access = cast(GLenum)checkIntParam(t, 2);
		auto size = checkIntParam(t, 3);

		if(size < 0 || size > uword.max)
			throwStdException(t, "RangeException", "Invalid size: {}", size);

		auto ptr = glMapBuffer(target, access);

		if(ptr is null)
		{
			version(CrocGLCheckErrors)
				throwNamedException(t, "GLException", "glMapBuffer - {}", fromStringz(cast(char*)gluErrorString(glGetError())));
			else
			{
				pushNull(t);
				return 1;
			}
		}

		auto arr = (cast(ubyte*)ptr)[0 .. cast(uword)size];

		if(optParam(t, 4, CrocValue.Type.Memblock))
		{
			memblockReviewDArray(t, 4, arr);
			dup(t, 4);
		}
		else
			memblockViewDArray(t, arr);

		return 1;
	}
	
	version(CrocGLCheckErrors)
	{
		void checkError(CrocThread* t, char[] funcName)
		{
			getRegistryVar(t, "gl.insideBeginEnd");
			bool insideBeginEnd = getBool(t, -1);
			pop(t);
	
			if(!insideBeginEnd)
			{
				auto err = glGetError();
	
				if(err != GL_NO_ERROR)
					throwNamedException(t, "GLException", "{} - {}", funcName, fromStringz(cast(char*)gluErrorString(err)));
			}
		}
	}

	// Loads OpenGL 1.0, 1.1, and glu
	void loadGLBase(CrocThread* t)
	{
		// gl 1.0
		register(t, &wrapGL!(glClearIndex), "glClearIndex");
		register(t, &wrapGL!(glClearColor), "glClearColor");
		register(t, &wrapGL!(glClear), "glClear");
		register(t, &wrapGL!(glIndexMask), "glIndexMask");
		register(t, &wrapGL!(glColorMask), "glColorMask");
		register(t, &wrapGL!(glAlphaFunc), "glAlphaFunc");
		register(t, &wrapGL!(glBlendFunc), "glBlendFunc");
		register(t, &wrapGL!(glLogicOp), "glLogicOp");
		register(t, &wrapGL!(glCullFace), "glCullFace");
		register(t, &wrapGL!(glFrontFace), "glFrontFace");
		register(t, &wrapGL!(glPointSize), "glPointSize");
		register(t, &wrapGL!(glLineWidth), "glLineWidth");
		register(t, &wrapGL!(glLineStipple), "glLineStipple");
		register(t, &wrapGL!(glPolygonMode), "glPolygonMode");
		register(t, &wrapGL!(glPolygonOffset), "glPolygonOffset");
		register(t, &wrapGL!(glPolygonStipple), "glPolygonStipple");
		register(t, &wrapGL!(glGetPolygonStipple), "glGetPolygonStipple");
		register(t, &wrapGL!(glEdgeFlag), "glEdgeFlag");
		register(t, &wrapGL!(glEdgeFlagv), "glEdgeFlagv");
		register(t, &wrapGL!(glScissor), "glScissor");
		register(t, &wrapGL!(glClipPlane), "glClipPlane");
		register(t, &wrapGL!(glGetClipPlane), "glGetClipPlane");
		register(t, &wrapGL!(glDrawBuffer), "glDrawBuffer");
		register(t, &wrapGL!(glReadBuffer), "glReadBuffer");
		register(t, &wrapGL!(glEnable), "glEnable");
		register(t, &wrapGL!(glDisable), "glDisable");
		register(t, &wrapGL!(glIsEnabled), "glIsEnabled");
		register(t, &wrapGL!(glEnableClientState), "glEnableClientState");
		register(t, &wrapGL!(glDisableClientState), "glDisableClientState");
		register(t, &wrapGL!(glGetBooleanv), "glGetBooleanv");
		register(t, &wrapGL!(glGetDoublev), "glGetDoublev");
		register(t, &wrapGL!(glGetFloatv), "glGetFloatv");
		register(t, &wrapGL!(glGetIntegerv), "glGetIntegerv");
		register(t, &wrapGL!(glPushAttrib), "glPushAttrib");
		register(t, &wrapGL!(glPopAttrib), "glPopAttrib");
		register(t, &wrapGL!(glPushClientAttrib), "glPushClientAttrib");
		register(t, &wrapGL!(glPopClientAttrib), "glPopClientAttrib");
		register(t, &wrapGL!(glRenderMode), "glRenderMode");
		register(t, &wrapGL!(glGetError), "glGetError");
		register(t, &wrapGL!(glGetString), "glGetString");
		register(t, &wrapGL!(glFinish), "glFinish");
		register(t, &wrapGL!(glFlush), "glFlush");
		register(t, &wrapGL!(glHint), "glHint");
		register(t, &wrapGL!(glClearDepth), "glClearDepth");
		register(t, &wrapGL!(glDepthFunc), "glDepthFunc");
		register(t, &wrapGL!(glDepthMask), "glDepthMask");
		register(t, &wrapGL!(glDepthRange), "glDepthRange");
		register(t, &wrapGL!(glClearAccum), "glClearAccum");
		register(t, &wrapGL!(glAccum), "glAccum");
		register(t, &wrapGL!(glMatrixMode), "glMatrixMode");
		register(t, &wrapGL!(glOrtho), "glOrtho");
		register(t, &wrapGL!(glFrustum), "glFrustum");
		register(t, &wrapGL!(glViewport), "glViewport");
		register(t, &wrapGL!(glPushMatrix), "glPushMatrix");
		register(t, &wrapGL!(glPopMatrix), "glPopMatrix");
		register(t, &wrapGL!(glLoadIdentity), "glLoadIdentity");
		register(t, &wrapGL!(glLoadMatrixd), "glLoadMatrixd");
		register(t, &wrapGL!(glLoadMatrixf), "glLoadMatrixf");
		register(t, &wrapGL!(glMultMatrixd), "glMultMatrixd");
		register(t, &wrapGL!(glMultMatrixf), "glMultMatrixf");
		register(t, &wrapGL!(glRotated), "glRotated");
		register(t, &wrapGL!(glRotatef), "glRotatef");
		register(t, &wrapGL!(glScaled), "glScaled");
		register(t, &wrapGL!(glScalef), "glScalef");
		register(t, &wrapGL!(glTranslated), "glTranslated");
		register(t, &wrapGL!(glTranslatef), "glTranslatef");
		register(t, &wrapGL!(glIsList), "glIsList");
		register(t, &wrapGL!(glDeleteLists), "glDeleteLists");
		register(t, &wrapGL!(glGenLists), "glGenLists");
		register(t, &wrapGL!(glNewList), "glNewList");
		register(t, &wrapGL!(glEndList), "glEndList");
		register(t, &wrapGL!(glCallList), "glCallList");
		register(t, &wrapGL!(glCallLists), "glCallLists");
		register(t, &wrapGL!(glListBase), "glListBase");
		register(t, &wrapGL!(glBegin), "glBegin");
		register(t, &wrapGL!(glEnd), "glEnd");
		register(t, &wrapGL!(glVertex2d), "glVertex2d");
		register(t, &wrapGL!(glVertex2f), "glVertex2f");
		register(t, &wrapGL!(glVertex2i), "glVertex2i");
		register(t, &wrapGL!(glVertex2s), "glVertex2s");
		register(t, &wrapGL!(glVertex3d), "glVertex3d");
		register(t, &wrapGL!(glVertex3f), "glVertex3f");
		register(t, &wrapGL!(glVertex3i), "glVertex3i");
		register(t, &wrapGL!(glVertex3s), "glVertex3s");
		register(t, &wrapGL!(glVertex4d), "glVertex4d");
		register(t, &wrapGL!(glVertex4f), "glVertex4f");
		register(t, &wrapGL!(glVertex4i), "glVertex4i");
		register(t, &wrapGL!(glVertex4s), "glVertex4s");
		register(t, &wrapGL!(glVertex2dv), "glVertex2dv");
		register(t, &wrapGL!(glVertex2fv), "glVertex2fv");
		register(t, &wrapGL!(glVertex2iv), "glVertex2iv");
		register(t, &wrapGL!(glVertex2sv), "glVertex2sv");
		register(t, &wrapGL!(glVertex3dv), "glVertex3dv");
		register(t, &wrapGL!(glVertex3fv), "glVertex3fv");
		register(t, &wrapGL!(glVertex3iv), "glVertex3iv");
		register(t, &wrapGL!(glVertex3sv), "glVertex3sv");
		register(t, &wrapGL!(glVertex4dv), "glVertex4dv");
		register(t, &wrapGL!(glVertex4fv), "glVertex4fv");
		register(t, &wrapGL!(glVertex4iv), "glVertex4iv");
		register(t, &wrapGL!(glVertex4sv), "glVertex4sv");
		register(t, &wrapGL!(glNormal3b), "glNormal3b");
		register(t, &wrapGL!(glNormal3d), "glNormal3d");
		register(t, &wrapGL!(glNormal3f), "glNormal3f");
		register(t, &wrapGL!(glNormal3i), "glNormal3i");
		register(t, &wrapGL!(glNormal3s), "glNormal3s");
		register(t, &wrapGL!(glNormal3bv), "glNormal3bv");
		register(t, &wrapGL!(glNormal3dv), "glNormal3dv");
		register(t, &wrapGL!(glNormal3fv), "glNormal3fv");
		register(t, &wrapGL!(glNormal3iv), "glNormal3iv");
		register(t, &wrapGL!(glNormal3sv), "glNormal3sv");
		register(t, &wrapGL!(glIndexd), "glIndexd");
		register(t, &wrapGL!(glIndexf), "glIndexf");
		register(t, &wrapGL!(glIndexi), "glIndexi");
		register(t, &wrapGL!(glIndexs), "glIndexs");
		register(t, &wrapGL!(glIndexub), "glIndexub");
		register(t, &wrapGL!(glIndexdv), "glIndexdv");
		register(t, &wrapGL!(glIndexfv), "glIndexfv");
		register(t, &wrapGL!(glIndexiv), "glIndexiv");
		register(t, &wrapGL!(glIndexsv), "glIndexsv");
		register(t, &wrapGL!(glIndexubv), "glIndexubv");
		register(t, &wrapGL!(glColor3b), "glColor3b");
		register(t, &wrapGL!(glColor3d), "glColor3d");
		register(t, &wrapGL!(glColor3f), "glColor3f");
		register(t, &wrapGL!(glColor3i), "glColor3i");
		register(t, &wrapGL!(glColor3s), "glColor3s");
		register(t, &wrapGL!(glColor3ub), "glColor3ub");
		register(t, &wrapGL!(glColor3ui), "glColor3ui");
		register(t, &wrapGL!(glColor3us), "glColor3us");
		register(t, &wrapGL!(glColor4b), "glColor4b");
		register(t, &wrapGL!(glColor4d), "glColor4d");
		register(t, &wrapGL!(glColor4f), "glColor4f");
		register(t, &wrapGL!(glColor4i), "glColor4i");
		register(t, &wrapGL!(glColor4s), "glColor4s");
		register(t, &wrapGL!(glColor4ub), "glColor4ub");
		register(t, &wrapGL!(glColor4ui), "glColor4ui");
		register(t, &wrapGL!(glColor4us), "glColor4us");
		register(t, &wrapGL!(glColor3bv), "glColor3bv");
		register(t, &wrapGL!(glColor3dv), "glColor3dv");
		register(t, &wrapGL!(glColor3fv), "glColor3fv");
		register(t, &wrapGL!(glColor3iv), "glColor3iv");
		register(t, &wrapGL!(glColor3sv), "glColor3sv");
		register(t, &wrapGL!(glColor3ubv), "glColor3ubv");
		register(t, &wrapGL!(glColor3uiv), "glColor3uiv");
		register(t, &wrapGL!(glColor3usv), "glColor3usv");
		register(t, &wrapGL!(glColor4bv), "glColor4bv");
		register(t, &wrapGL!(glColor4dv), "glColor4dv");
		register(t, &wrapGL!(glColor4fv), "glColor4fv");
		register(t, &wrapGL!(glColor4iv), "glColor4iv");
		register(t, &wrapGL!(glColor4sv), "glColor4sv");
		register(t, &wrapGL!(glColor4ubv), "glColor4ubv");
		register(t, &wrapGL!(glColor4uiv), "glColor4uiv");
		register(t, &wrapGL!(glColor4usv), "glColor4usv");
		register(t, &wrapGL!(glTexCoord1d), "glTexCoord1d");
		register(t, &wrapGL!(glTexCoord1f), "glTexCoord1f");
		register(t, &wrapGL!(glTexCoord1i), "glTexCoord1i");
		register(t, &wrapGL!(glTexCoord1s), "glTexCoord1s");
		register(t, &wrapGL!(glTexCoord2d), "glTexCoord2d");
		register(t, &wrapGL!(glTexCoord2f), "glTexCoord2f");
		register(t, &wrapGL!(glTexCoord2i), "glTexCoord2i");
		register(t, &wrapGL!(glTexCoord2s), "glTexCoord2s");
		register(t, &wrapGL!(glTexCoord3d), "glTexCoord3d");
		register(t, &wrapGL!(glTexCoord3f), "glTexCoord3f");
		register(t, &wrapGL!(glTexCoord3i), "glTexCoord3i");
		register(t, &wrapGL!(glTexCoord3s), "glTexCoord3s");
		register(t, &wrapGL!(glTexCoord4d), "glTexCoord4d");
		register(t, &wrapGL!(glTexCoord4f), "glTexCoord4f");
		register(t, &wrapGL!(glTexCoord4i), "glTexCoord4i");
		register(t, &wrapGL!(glTexCoord4s), "glTexCoord4s");
		register(t, &wrapGL!(glTexCoord1dv), "glTexCoord1dv");
		register(t, &wrapGL!(glTexCoord1fv), "glTexCoord1fv");
		register(t, &wrapGL!(glTexCoord1iv), "glTexCoord1iv");
		register(t, &wrapGL!(glTexCoord1sv), "glTexCoord1sv");
		register(t, &wrapGL!(glTexCoord2dv), "glTexCoord2dv");
		register(t, &wrapGL!(glTexCoord2fv), "glTexCoord2fv");
		register(t, &wrapGL!(glTexCoord2iv), "glTexCoord2iv");
		register(t, &wrapGL!(glTexCoord2sv), "glTexCoord2sv");
		register(t, &wrapGL!(glTexCoord3dv), "glTexCoord3dv");
		register(t, &wrapGL!(glTexCoord3fv), "glTexCoord3fv");
		register(t, &wrapGL!(glTexCoord3iv), "glTexCoord3iv");
		register(t, &wrapGL!(glTexCoord3sv), "glTexCoord3sv");
		register(t, &wrapGL!(glTexCoord4dv), "glTexCoord4dv");
		register(t, &wrapGL!(glTexCoord4fv), "glTexCoord4fv");
		register(t, &wrapGL!(glTexCoord4iv), "glTexCoord4iv");
		register(t, &wrapGL!(glTexCoord4sv), "glTexCoord4sv");
		register(t, &wrapGL!(glRasterPos2d), "glRasterPos2d");
		register(t, &wrapGL!(glRasterPos2f), "glRasterPos2f");
		register(t, &wrapGL!(glRasterPos2i), "glRasterPos2i");
		register(t, &wrapGL!(glRasterPos2s), "glRasterPos2s");
		register(t, &wrapGL!(glRasterPos3d), "glRasterPos3d");
		register(t, &wrapGL!(glRasterPos3f), "glRasterPos3f");
		register(t, &wrapGL!(glRasterPos3i), "glRasterPos3i");
		register(t, &wrapGL!(glRasterPos3s), "glRasterPos3s");
		register(t, &wrapGL!(glRasterPos4d), "glRasterPos4d");
		register(t, &wrapGL!(glRasterPos4f), "glRasterPos4f");
		register(t, &wrapGL!(glRasterPos4i), "glRasterPos4i");
		register(t, &wrapGL!(glRasterPos4s), "glRasterPos4s");
		register(t, &wrapGL!(glRasterPos2dv), "glRasterPos2dv");
		register(t, &wrapGL!(glRasterPos2fv), "glRasterPos2fv");
		register(t, &wrapGL!(glRasterPos2iv), "glRasterPos2iv");
		register(t, &wrapGL!(glRasterPos2sv), "glRasterPos2sv");
		register(t, &wrapGL!(glRasterPos3dv), "glRasterPos3dv");
		register(t, &wrapGL!(glRasterPos3fv), "glRasterPos3fv");
		register(t, &wrapGL!(glRasterPos3iv), "glRasterPos3iv");
		register(t, &wrapGL!(glRasterPos3sv), "glRasterPos3sv");
		register(t, &wrapGL!(glRasterPos4dv), "glRasterPos4dv");
		register(t, &wrapGL!(glRasterPos4fv), "glRasterPos4fv");
		register(t, &wrapGL!(glRasterPos4iv), "glRasterPos4iv");
		register(t, &wrapGL!(glRasterPos4sv), "glRasterPos4sv");
		register(t, &wrapGL!(glRectd), "glRectd");
		register(t, &wrapGL!(glRectf), "glRectf");
		register(t, &wrapGL!(glRecti), "glRecti");
		register(t, &wrapGL!(glRects), "glRects");
		register(t, &wrapGL!(glRectdv), "glRectdv");
		register(t, &wrapGL!(glRectfv), "glRectfv");
		register(t, &wrapGL!(glRectiv), "glRectiv");
		register(t, &wrapGL!(glRectsv), "glRectsv");
		register(t, &wrapGL!(glShadeModel), "glShadeModel");
		register(t, &wrapGL!(glLightf), "glLightf");
		register(t, &wrapGL!(glLighti), "glLighti");
		register(t, &wrapGL!(glLightfv), "glLightfv");
		register(t, &wrapGL!(glLightiv), "glLightiv");
		register(t, &wrapGL!(glGetLightfv), "glGetLightfv");
		register(t, &wrapGL!(glGetLightiv), "glGetLightiv");
		register(t, &wrapGL!(glLightModelf), "glLightModelf");
		register(t, &wrapGL!(glLightModeli), "glLightModeli");
		register(t, &wrapGL!(glLightModelfv), "glLightModelfv");
		register(t, &wrapGL!(glLightModeliv), "glLightModeliv");
		register(t, &wrapGL!(glMaterialf), "glMaterialf");
		register(t, &wrapGL!(glMateriali), "glMateriali");
		register(t, &wrapGL!(glMaterialfv), "glMaterialfv");
		register(t, &wrapGL!(glMaterialiv), "glMaterialiv");
		register(t, &wrapGL!(glGetMaterialfv), "glGetMaterialfv");
		register(t, &wrapGL!(glGetMaterialiv), "glGetMaterialiv");
		register(t, &wrapGL!(glColorMaterial), "glColorMaterial");
		register(t, &wrapGL!(glPixelZoom), "glPixelZoom");
		register(t, &wrapGL!(glPixelStoref), "glPixelStoref");
		register(t, &wrapGL!(glPixelStorei), "glPixelStorei");
		register(t, &wrapGL!(glPixelTransferf), "glPixelTransferf");
		register(t, &wrapGL!(glPixelTransferi), "glPixelTransferi");
		register(t, &wrapGL!(glPixelMapfv), "glPixelMapfv");
		register(t, &wrapGL!(glPixelMapuiv), "glPixelMapuiv");
		register(t, &wrapGL!(glPixelMapusv), "glPixelMapusv");
		register(t, &wrapGL!(glGetPixelMapfv), "glGetPixelMapfv");
		register(t, &wrapGL!(glGetPixelMapuiv), "glGetPixelMapuiv");
		register(t, &wrapGL!(glGetPixelMapusv), "glGetPixelMapusv");
		register(t, &wrapGL!(glBitmap), "glBitmap");
		register(t, &wrapGL!(glReadPixels), "glReadPixels");
		register(t, &wrapGL!(glDrawPixels), "glDrawPixels");
		register(t, &wrapGL!(glCopyPixels), "glCopyPixels");
		register(t, &wrapGL!(glStencilFunc), "glStencilFunc");
		register(t, &wrapGL!(glStencilMask), "glStencilMask");
		register(t, &wrapGL!(glStencilOp), "glStencilOp");
		register(t, &wrapGL!(glClearStencil), "glClearStencil");
		register(t, &wrapGL!(glTexGend), "glTexGend");
		register(t, &wrapGL!(glTexGenf), "glTexGenf");
		register(t, &wrapGL!(glTexGeni), "glTexGeni");
		register(t, &wrapGL!(glTexGendv), "glTexGendv");
		register(t, &wrapGL!(glTexGenfv), "glTexGenfv");
		register(t, &wrapGL!(glTexGeniv), "glTexGeniv");
		register(t, &wrapGL!(glTexEnvf), "glTexEnvf");
		register(t, &wrapGL!(glTexEnvi), "glTexEnvi");
		register(t, &wrapGL!(glTexEnvfv), "glTexEnvfv");
		register(t, &wrapGL!(glTexEnviv), "glTexEnviv");
		register(t, &wrapGL!(glGetTexEnvfv), "glGetTexEnvfv");
		register(t, &wrapGL!(glGetTexEnviv), "glGetTexEnviv");
		register(t, &wrapGL!(glTexParameterf), "glTexParameterf");
		register(t, &wrapGL!(glTexParameteri), "glTexParameteri");
		register(t, &wrapGL!(glTexParameterfv), "glTexParameterfv");
		register(t, &wrapGL!(glTexParameteriv), "glTexParameteriv");
		register(t, &wrapGL!(glGetTexParameterfv), "glGetTexParameterfv");
		register(t, &wrapGL!(glGetTexParameteriv), "glGetTexParameteriv");
		register(t, &wrapGL!(glGetTexLevelParameterfv), "glGetTexLevelParameterfv");
		register(t, &wrapGL!(glGetTexLevelParameteriv), "glGetTexLevelParameteriv");
		register(t, &wrapGL!(glTexImage1D), "glTexImage1D");
		register(t, &wrapGL!(glTexImage2D), "glTexImage2D");
		register(t, &wrapGL!(glGetTexImage), "glGetTexImage");
		register(t, &wrapGL!(glMap1d), "glMap1d");
		register(t, &wrapGL!(glMap1f), "glMap1f");
		register(t, &wrapGL!(glMap2d), "glMap2d");
		register(t, &wrapGL!(glMap2f), "glMap2f");
		register(t, &wrapGL!(glGetMapdv), "glGetMapdv");
		register(t, &wrapGL!(glGetMapfv), "glGetMapfv");
		register(t, &wrapGL!(glEvalCoord1d), "glEvalCoord1d");
		register(t, &wrapGL!(glEvalCoord1f), "glEvalCoord1f");
		register(t, &wrapGL!(glEvalCoord1dv), "glEvalCoord1dv");
		register(t, &wrapGL!(glEvalCoord1fv), "glEvalCoord1fv");
		register(t, &wrapGL!(glEvalCoord2d), "glEvalCoord2d");
		register(t, &wrapGL!(glEvalCoord2f), "glEvalCoord2f");
		register(t, &wrapGL!(glEvalCoord2dv), "glEvalCoord2dv");
		register(t, &wrapGL!(glEvalCoord2fv), "glEvalCoord2fv");
		register(t, &wrapGL!(glMapGrid1d), "glMapGrid1d");
		register(t, &wrapGL!(glMapGrid1f), "glMapGrid1f");
		register(t, &wrapGL!(glMapGrid2d), "glMapGrid2d");
		register(t, &wrapGL!(glMapGrid2f), "glMapGrid2f");
		register(t, &wrapGL!(glEvalPoint1), "glEvalPoint1");
		register(t, &wrapGL!(glEvalPoint2), "glEvalPoint2");
		register(t, &wrapGL!(glEvalMesh1), "glEvalMesh1");
		register(t, &wrapGL!(glEvalMesh2), "glEvalMesh2");
		register(t, &wrapGL!(glFogf), "glFogf");
		register(t, &wrapGL!(glFogi), "glFogi");
		register(t, &wrapGL!(glFogfv), "glFogfv");
		register(t, &wrapGL!(glFogiv), "glFogiv");
		register(t, &wrapGL!(glFeedbackBuffer), "glFeedbackBuffer");
		register(t, &wrapGL!(glPassThrough), "glPassThrough");
		register(t, &wrapGL!(glSelectBuffer), "glSelectBuffer");
		register(t, &wrapGL!(glInitNames), "glInitNames");
		register(t, &wrapGL!(glLoadName), "glLoadName");
		register(t, &wrapGL!(glPushName), "glPushName");
		register(t, &wrapGL!(glPopName), "glPopName");

		pushInt(t, GL_BYTE); newGlobal(t, "GL_BYTE");
		pushInt(t, GL_UNSIGNED_BYTE); newGlobal(t, "GL_UNSIGNED_BYTE");
		pushInt(t, GL_SHORT); newGlobal(t, "GL_SHORT");
		pushInt(t, GL_UNSIGNED_SHORT); newGlobal(t, "GL_UNSIGNED_SHORT");
		pushInt(t, GL_INT); newGlobal(t, "GL_INT");
		pushInt(t, GL_UNSIGNED_INT); newGlobal(t, "GL_UNSIGNED_INT");
		pushInt(t, GL_FLOAT); newGlobal(t, "GL_FLOAT");
		pushInt(t, GL_DOUBLE); newGlobal(t, "GL_DOUBLE");
		pushInt(t, GL_2_BYTES); newGlobal(t, "2_BYTES");
		pushInt(t, GL_3_BYTES); newGlobal(t, "3_BYTES");
		pushInt(t, GL_4_BYTES); newGlobal(t, "4_BYTES");
		pushInt(t, GL_POINTS); newGlobal(t, "GL_POINTS");
		pushInt(t, GL_LINES); newGlobal(t, "GL_LINES");
		pushInt(t, GL_LINE_LOOP); newGlobal(t, "GL_LINE_LOOP");
		pushInt(t, GL_LINE_STRIP); newGlobal(t, "GL_LINE_STRIP");
		pushInt(t, GL_TRIANGLES); newGlobal(t, "GL_TRIANGLES");
		pushInt(t, GL_TRIANGLE_STRIP); newGlobal(t, "GL_TRIANGLE_STRIP");
		pushInt(t, GL_TRIANGLE_FAN); newGlobal(t, "GL_TRIANGLE_FAN");
		pushInt(t, GL_QUADS); newGlobal(t, "GL_QUADS");
		pushInt(t, GL_QUAD_STRIP); newGlobal(t, "GL_QUAD_STRIP");
		pushInt(t, GL_POLYGON); newGlobal(t, "GL_POLYGON");
		pushInt(t, GL_VERTEX_ARRAY); newGlobal(t, "GL_VERTEX_ARRAY");
		pushInt(t, GL_NORMAL_ARRAY); newGlobal(t, "GL_NORMAL_ARRAY");
		pushInt(t, GL_COLOR_ARRAY); newGlobal(t, "GL_COLOR_ARRAY");
		pushInt(t, GL_INDEX_ARRAY); newGlobal(t, "GL_INDEX_ARRAY");
		pushInt(t, GL_TEXTURE_COORD_ARRAY); newGlobal(t, "GL_TEXTURE_COORD_ARRAY");
		pushInt(t, GL_EDGE_FLAG_ARRAY); newGlobal(t, "GL_EDGE_FLAG_ARRAY");
		pushInt(t, GL_VERTEX_ARRAY_SIZE); newGlobal(t, "GL_VERTEX_ARRAY_SIZE");
		pushInt(t, GL_VERTEX_ARRAY_TYPE); newGlobal(t, "GL_VERTEX_ARRAY_TYPE");
		pushInt(t, GL_VERTEX_ARRAY_STRIDE); newGlobal(t, "GL_VERTEX_ARRAY_STRIDE");
		pushInt(t, GL_NORMAL_ARRAY_TYPE); newGlobal(t, "GL_NORMAL_ARRAY_TYPE");
		pushInt(t, GL_NORMAL_ARRAY_STRIDE); newGlobal(t, "GL_NORMAL_ARRAY_STRIDE");
		pushInt(t, GL_COLOR_ARRAY_SIZE); newGlobal(t, "GL_COLOR_ARRAY_SIZE");
		pushInt(t, GL_COLOR_ARRAY_TYPE); newGlobal(t, "GL_COLOR_ARRAY_TYPE");
		pushInt(t, GL_COLOR_ARRAY_STRIDE); newGlobal(t, "GL_COLOR_ARRAY_STRIDE");
		pushInt(t, GL_INDEX_ARRAY_TYPE); newGlobal(t, "GL_INDEX_ARRAY_TYPE");
		pushInt(t, GL_INDEX_ARRAY_STRIDE); newGlobal(t, "GL_INDEX_ARRAY_STRIDE");
		pushInt(t, GL_TEXTURE_COORD_ARRAY_SIZE); newGlobal(t, "GL_TEXTURE_COORD_ARRAY_SIZE");
		pushInt(t, GL_TEXTURE_COORD_ARRAY_TYPE); newGlobal(t, "GL_TEXTURE_COORD_ARRAY_TYPE");
		pushInt(t, GL_TEXTURE_COORD_ARRAY_STRIDE); newGlobal(t, "GL_TEXTURE_COORD_ARRAY_STRIDE");
		pushInt(t, GL_EDGE_FLAG_ARRAY_STRIDE); newGlobal(t, "GL_EDGE_FLAG_ARRAY_STRIDE");
		pushInt(t, GL_VERTEX_ARRAY_POINTER); newGlobal(t, "GL_VERTEX_ARRAY_POINTER");
		pushInt(t, GL_NORMAL_ARRAY_POINTER); newGlobal(t, "GL_NORMAL_ARRAY_POINTER");
		pushInt(t, GL_COLOR_ARRAY_POINTER); newGlobal(t, "GL_COLOR_ARRAY_POINTER");
		pushInt(t, GL_INDEX_ARRAY_POINTER); newGlobal(t, "GL_INDEX_ARRAY_POINTER");
		pushInt(t, GL_TEXTURE_COORD_ARRAY_POINTER); newGlobal(t, "GL_TEXTURE_COORD_ARRAY_POINTER");
		pushInt(t, GL_EDGE_FLAG_ARRAY_POINTER); newGlobal(t, "GL_EDGE_FLAG_ARRAY_POINTER");
		pushInt(t, GL_V2F); newGlobal(t, "GL_V2F");
		pushInt(t, GL_V3F); newGlobal(t, "GL_V3F");
		pushInt(t, GL_C4UB_V2F); newGlobal(t, "GL_C4UB_V2F");
		pushInt(t, GL_C4UB_V3F); newGlobal(t, "GL_C4UB_V3F");
		pushInt(t, GL_C3F_V3F); newGlobal(t, "GL_C3F_V3F");
		pushInt(t, GL_N3F_V3F); newGlobal(t, "GL_N3F_V3F");
		pushInt(t, GL_C4F_N3F_V3F); newGlobal(t, "GL_C4F_N3F_V3F");
		pushInt(t, GL_T2F_V3F); newGlobal(t, "GL_T2F_V3F");
		pushInt(t, GL_T4F_V4F); newGlobal(t, "GL_T4F_V4F");
		pushInt(t, GL_T2F_C4UB_V3F); newGlobal(t, "GL_T2F_C4UB_V3F");
		pushInt(t, GL_T2F_C3F_V3F); newGlobal(t, "GL_T2F_C3F_V3F");
		pushInt(t, GL_T2F_N3F_V3F); newGlobal(t, "GL_T2F_N3F_V3F");
		pushInt(t, GL_T2F_C4F_N3F_V3F); newGlobal(t, "GL_T2F_C4F_N3F_V3F");
		pushInt(t, GL_T4F_C4F_N3F_V4F); newGlobal(t, "GL_T4F_C4F_N3F_V4F");
		pushInt(t, GL_MATRIX_MODE); newGlobal(t, "GL_MATRIX_MODE");
		pushInt(t, GL_MODELVIEW); newGlobal(t, "GL_MODELVIEW");
		pushInt(t, GL_PROJECTION); newGlobal(t, "GL_PROJECTION");
		pushInt(t, GL_TEXTURE); newGlobal(t, "GL_TEXTURE");
		pushInt(t, GL_POINT_SMOOTH); newGlobal(t, "GL_POINT_SMOOTH");
		pushInt(t, GL_POINT_SIZE); newGlobal(t, "GL_POINT_SIZE");
		pushInt(t, GL_POINT_SIZE_GRANULARITY); newGlobal(t, "GL_POINT_SIZE_GRANULARITY");
		pushInt(t, GL_POINT_SIZE_RANGE); newGlobal(t, "GL_POINT_SIZE_RANGE");
		pushInt(t, GL_LINE_SMOOTH); newGlobal(t, "GL_LINE_SMOOTH");
		pushInt(t, GL_LINE_STIPPLE); newGlobal(t, "GL_LINE_STIPPLE");
		pushInt(t, GL_LINE_STIPPLE_PATTERN); newGlobal(t, "GL_LINE_STIPPLE_PATTERN");
		pushInt(t, GL_LINE_STIPPLE_REPEAT); newGlobal(t, "GL_LINE_STIPPLE_REPEAT");
		pushInt(t, GL_LINE_WIDTH); newGlobal(t, "GL_LINE_WIDTH");
		pushInt(t, GL_LINE_WIDTH_GRANULARITY); newGlobal(t, "GL_LINE_WIDTH_GRANULARITY");
		pushInt(t, GL_LINE_WIDTH_RANGE); newGlobal(t, "GL_LINE_WIDTH_RANGE");
		pushInt(t, GL_POINT); newGlobal(t, "GL_POINT");
		pushInt(t, GL_LINE); newGlobal(t, "GL_LINE");
		pushInt(t, GL_FILL); newGlobal(t, "GL_FILL");
		pushInt(t, GL_CW); newGlobal(t, "GL_CW");
		pushInt(t, GL_CCW); newGlobal(t, "GL_CCW");
		pushInt(t, GL_FRONT); newGlobal(t, "GL_FRONT");
		pushInt(t, GL_BACK); newGlobal(t, "GL_BACK");
		pushInt(t, GL_POLYGON_MODE); newGlobal(t, "GL_POLYGON_MODE");
		pushInt(t, GL_POLYGON_SMOOTH); newGlobal(t, "GL_POLYGON_SMOOTH");
		pushInt(t, GL_POLYGON_STIPPLE); newGlobal(t, "GL_POLYGON_STIPPLE");
		pushInt(t, GL_EDGE_FLAG); newGlobal(t, "GL_EDGE_FLAG");
		pushInt(t, GL_CULL_FACE); newGlobal(t, "GL_CULL_FACE");
		pushInt(t, GL_CULL_FACE_MODE); newGlobal(t, "GL_CULL_FACE_MODE");
		pushInt(t, GL_FRONT_FACE); newGlobal(t, "GL_FRONT_FACE");
		pushInt(t, GL_POLYGON_OFFSET_FACTOR); newGlobal(t, "GL_POLYGON_OFFSET_FACTOR");
		pushInt(t, GL_POLYGON_OFFSET_UNITS); newGlobal(t, "GL_POLYGON_OFFSET_UNITS");
		pushInt(t, GL_POLYGON_OFFSET_POINT); newGlobal(t, "GL_POLYGON_OFFSET_POINT");
		pushInt(t, GL_POLYGON_OFFSET_LINE); newGlobal(t, "GL_POLYGON_OFFSET_LINE");
		pushInt(t, GL_POLYGON_OFFSET_FILL); newGlobal(t, "GL_POLYGON_OFFSET_FILL");
		pushInt(t, GL_COMPILE); newGlobal(t, "GL_COMPILE");
		pushInt(t, GL_COMPILE_AND_EXECUTE); newGlobal(t, "GL_COMPILE_AND_EXECUTE");
		pushInt(t, GL_LIST_BASE); newGlobal(t, "GL_LIST_BASE");
		pushInt(t, GL_LIST_INDEX); newGlobal(t, "GL_LIST_INDEX");
		pushInt(t, GL_LIST_MODE); newGlobal(t, "GL_LIST_MODE");
		pushInt(t, GL_NEVER); newGlobal(t, "GL_NEVER");
		pushInt(t, GL_LESS); newGlobal(t, "GL_LESS");
		pushInt(t, GL_EQUAL); newGlobal(t, "GL_EQUAL");
		pushInt(t, GL_LEQUAL); newGlobal(t, "GL_LEQUAL");
		pushInt(t, GL_GREATER); newGlobal(t, "GL_GREATER");
		pushInt(t, GL_NOTEQUAL); newGlobal(t, "GL_NOTEQUAL");
		pushInt(t, GL_GEQUAL); newGlobal(t, "GL_GEQUAL");
		pushInt(t, GL_ALWAYS); newGlobal(t, "GL_ALWAYS");
		pushInt(t, GL_DEPTH_TEST); newGlobal(t, "GL_DEPTH_TEST");
		pushInt(t, GL_DEPTH_BITS); newGlobal(t, "GL_DEPTH_BITS");
		pushInt(t, GL_DEPTH_CLEAR_VALUE); newGlobal(t, "GL_DEPTH_CLEAR_VALUE");
		pushInt(t, GL_DEPTH_FUNC); newGlobal(t, "GL_DEPTH_FUNC");
		pushInt(t, GL_DEPTH_RANGE); newGlobal(t, "GL_DEPTH_RANGE");
		pushInt(t, GL_DEPTH_WRITEMASK); newGlobal(t, "GL_DEPTH_WRITEMASK");
		pushInt(t, GL_DEPTH_COMPONENT); newGlobal(t, "GL_DEPTH_COMPONENT");
		pushInt(t, GL_LIGHTING); newGlobal(t, "GL_LIGHTING");
		pushInt(t, GL_LIGHT0); newGlobal(t, "GL_LIGHT0");
		pushInt(t, GL_LIGHT1); newGlobal(t, "GL_LIGHT1");
		pushInt(t, GL_LIGHT2); newGlobal(t, "GL_LIGHT2");
		pushInt(t, GL_LIGHT3); newGlobal(t, "GL_LIGHT3");
		pushInt(t, GL_LIGHT4); newGlobal(t, "GL_LIGHT4");
		pushInt(t, GL_LIGHT5); newGlobal(t, "GL_LIGHT5");
		pushInt(t, GL_LIGHT6); newGlobal(t, "GL_LIGHT6");
		pushInt(t, GL_LIGHT7); newGlobal(t, "GL_LIGHT7");
		pushInt(t, GL_SPOT_EXPONENT); newGlobal(t, "GL_SPOT_EXPONENT");
		pushInt(t, GL_SPOT_CUTOFF); newGlobal(t, "GL_SPOT_CUTOFF");
		pushInt(t, GL_CONSTANT_ATTENUATION); newGlobal(t, "GL_CONSTANT_ATTENUATION");
		pushInt(t, GL_LINEAR_ATTENUATION); newGlobal(t, "GL_LINEAR_ATTENUATION");
		pushInt(t, GL_QUADRATIC_ATTENUATION); newGlobal(t, "GL_QUADRATIC_ATTENUATION");
		pushInt(t, GL_AMBIENT); newGlobal(t, "GL_AMBIENT");
		pushInt(t, GL_DIFFUSE); newGlobal(t, "GL_DIFFUSE");
		pushInt(t, GL_SPECULAR); newGlobal(t, "GL_SPECULAR");
		pushInt(t, GL_SHININESS); newGlobal(t, "GL_SHININESS");
		pushInt(t, GL_EMISSION); newGlobal(t, "GL_EMISSION");
		pushInt(t, GL_POSITION); newGlobal(t, "GL_POSITION");
		pushInt(t, GL_SPOT_DIRECTION); newGlobal(t, "GL_SPOT_DIRECTION");
		pushInt(t, GL_AMBIENT_AND_DIFFUSE); newGlobal(t, "GL_AMBIENT_AND_DIFFUSE");
		pushInt(t, GL_COLOR_INDEXES); newGlobal(t, "GL_COLOR_INDEXES");
		pushInt(t, GL_LIGHT_MODEL_TWO_SIDE); newGlobal(t, "GL_LIGHT_MODEL_TWO_SIDE");
		pushInt(t, GL_LIGHT_MODEL_LOCAL_VIEWER); newGlobal(t, "GL_LIGHT_MODEL_LOCAL_VIEWER");
		pushInt(t, GL_LIGHT_MODEL_AMBIENT); newGlobal(t, "GL_LIGHT_MODEL_AMBIENT");
		pushInt(t, GL_FRONT_AND_BACK); newGlobal(t, "GL_FRONT_AND_BACK");
		pushInt(t, GL_SHADE_MODEL); newGlobal(t, "GL_SHADE_MODEL");
		pushInt(t, GL_FLAT); newGlobal(t, "GL_FLAT");
		pushInt(t, GL_SMOOTH); newGlobal(t, "GL_SMOOTH");
		pushInt(t, GL_COLOR_MATERIAL); newGlobal(t, "GL_COLOR_MATERIAL");
		pushInt(t, GL_COLOR_MATERIAL_FACE); newGlobal(t, "GL_COLOR_MATERIAL_FACE");
		pushInt(t, GL_COLOR_MATERIAL_PARAMETER); newGlobal(t, "GL_COLOR_MATERIAL_PARAMETER");
		pushInt(t, GL_NORMALIZE); newGlobal(t, "GL_NORMALIZE");
		pushInt(t, GL_CLIP_PLANE0); newGlobal(t, "GL_CLIP_PLANE0");
		pushInt(t, GL_CLIP_PLANE1); newGlobal(t, "GL_CLIP_PLANE1");
		pushInt(t, GL_CLIP_PLANE2); newGlobal(t, "GL_CLIP_PLANE2");
		pushInt(t, GL_CLIP_PLANE3); newGlobal(t, "GL_CLIP_PLANE3");
		pushInt(t, GL_CLIP_PLANE4); newGlobal(t, "GL_CLIP_PLANE4");
		pushInt(t, GL_CLIP_PLANE5); newGlobal(t, "GL_CLIP_PLANE5");
		pushInt(t, GL_ACCUM_RED_BITS); newGlobal(t, "GL_ACCUM_RED_BITS");
		pushInt(t, GL_ACCUM_GREEN_BITS); newGlobal(t, "GL_ACCUM_GREEN_BITS");
		pushInt(t, GL_ACCUM_BLUE_BITS); newGlobal(t, "GL_ACCUM_BLUE_BITS");
		pushInt(t, GL_ACCUM_ALPHA_BITS); newGlobal(t, "GL_ACCUM_ALPHA_BITS");
		pushInt(t, GL_ACCUM_CLEAR_VALUE); newGlobal(t, "GL_ACCUM_CLEAR_VALUE");
		pushInt(t, GL_ACCUM); newGlobal(t, "GL_ACCUM");
		pushInt(t, GL_ADD); newGlobal(t, "GL_ADD");
		pushInt(t, GL_LOAD); newGlobal(t, "GL_LOAD");
		pushInt(t, GL_MULT); newGlobal(t, "GL_MULT");
		pushInt(t, GL_RETURN); newGlobal(t, "GL_RETURN");
		pushInt(t, GL_ALPHA_TEST); newGlobal(t, "GL_ALPHA_TEST");
		pushInt(t, GL_ALPHA_TEST_REF); newGlobal(t, "GL_ALPHA_TEST_REF");
		pushInt(t, GL_ALPHA_TEST_FUNC); newGlobal(t, "GL_ALPHA_TEST_FUNC");
		pushInt(t, GL_BLEND); newGlobal(t, "GL_BLEND");
		pushInt(t, GL_BLEND_SRC); newGlobal(t, "GL_BLEND_SRC");
		pushInt(t, GL_BLEND_DST); newGlobal(t, "GL_BLEND_DST");
		pushInt(t, GL_ZERO); newGlobal(t, "GL_ZERO");
		pushInt(t, GL_ONE); newGlobal(t, "GL_ONE");
		pushInt(t, GL_SRC_COLOR); newGlobal(t, "GL_SRC_COLOR");
		pushInt(t, GL_ONE_MINUS_SRC_COLOR); newGlobal(t, "GL_ONE_MINUS_SRC_COLOR");
		pushInt(t, GL_SRC_ALPHA); newGlobal(t, "GL_SRC_ALPHA");
		pushInt(t, GL_ONE_MINUS_SRC_ALPHA); newGlobal(t, "GL_ONE_MINUS_SRC_ALPHA");
		pushInt(t, GL_DST_ALPHA); newGlobal(t, "GL_DST_ALPHA");
		pushInt(t, GL_ONE_MINUS_DST_ALPHA); newGlobal(t, "GL_ONE_MINUS_DST_ALPHA");
		pushInt(t, GL_DST_COLOR); newGlobal(t, "GL_DST_COLOR");
		pushInt(t, GL_ONE_MINUS_DST_COLOR); newGlobal(t, "GL_ONE_MINUS_DST_COLOR");
		pushInt(t, GL_SRC_ALPHA_SATURATE); newGlobal(t, "GL_SRC_ALPHA_SATURATE");
		pushInt(t, GL_FEEDBACK); newGlobal(t, "GL_FEEDBACK");
		pushInt(t, GL_RENDER); newGlobal(t, "GL_RENDER");
		pushInt(t, GL_SELECT); newGlobal(t, "GL_SELECT");
		pushInt(t, GL_2D); newGlobal(t, "2D");
		pushInt(t, GL_3D); newGlobal(t, "3D");
		pushInt(t, GL_3D_COLOR); newGlobal(t, "3D_COLOR");
		pushInt(t, GL_3D_COLOR_TEXTURE); newGlobal(t, "3D_COLOR_TEXTURE");
		pushInt(t, GL_4D_COLOR_TEXTURE); newGlobal(t, "4D_COLOR_TEXTURE");
		pushInt(t, GL_POINT_TOKEN); newGlobal(t, "GL_POINT_TOKEN");
		pushInt(t, GL_LINE_TOKEN); newGlobal(t, "GL_LINE_TOKEN");
		pushInt(t, GL_LINE_RESET_TOKEN); newGlobal(t, "GL_LINE_RESET_TOKEN");
		pushInt(t, GL_POLYGON_TOKEN); newGlobal(t, "GL_POLYGON_TOKEN");
		pushInt(t, GL_BITMAP_TOKEN); newGlobal(t, "GL_BITMAP_TOKEN");
		pushInt(t, GL_DRAW_PIXEL_TOKEN); newGlobal(t, "GL_DRAW_PIXEL_TOKEN");
		pushInt(t, GL_COPY_PIXEL_TOKEN); newGlobal(t, "GL_COPY_PIXEL_TOKEN");
		pushInt(t, GL_PASS_THROUGH_TOKEN); newGlobal(t, "GL_PASS_THROUGH_TOKEN");
		pushInt(t, GL_FEEDBACK_BUFFER_POINTER); newGlobal(t, "GL_FEEDBACK_BUFFER_POINTER");
		pushInt(t, GL_FEEDBACK_BUFFER_SIZE); newGlobal(t, "GL_FEEDBACK_BUFFER_SIZE");
		pushInt(t, GL_FEEDBACK_BUFFER_TYPE); newGlobal(t, "GL_FEEDBACK_BUFFER_TYPE");
		pushInt(t, GL_SELECTION_BUFFER_POINTER); newGlobal(t, "GL_SELECTION_BUFFER_POINTER");
		pushInt(t, GL_SELECTION_BUFFER_SIZE); newGlobal(t, "GL_SELECTION_BUFFER_SIZE");
		pushInt(t, GL_FOG); newGlobal(t, "GL_FOG");
		pushInt(t, GL_FOG_MODE); newGlobal(t, "GL_FOG_MODE");
		pushInt(t, GL_FOG_DENSITY); newGlobal(t, "GL_FOG_DENSITY");
		pushInt(t, GL_FOG_COLOR); newGlobal(t, "GL_FOG_COLOR");
		pushInt(t, GL_FOG_INDEX); newGlobal(t, "GL_FOG_INDEX");
		pushInt(t, GL_FOG_START); newGlobal(t, "GL_FOG_START");
		pushInt(t, GL_FOG_END); newGlobal(t, "GL_FOG_END");
		pushInt(t, GL_LINEAR); newGlobal(t, "GL_LINEAR");
		pushInt(t, GL_EXP); newGlobal(t, "GL_EXP");
		pushInt(t, GL_EXP2); newGlobal(t, "GL_EXP2");
		pushInt(t, GL_LOGIC_OP); newGlobal(t, "GL_LOGIC_OP");
		pushInt(t, GL_INDEX_LOGIC_OP); newGlobal(t, "GL_INDEX_LOGIC_OP");
		pushInt(t, GL_COLOR_LOGIC_OP); newGlobal(t, "GL_COLOR_LOGIC_OP");
		pushInt(t, GL_LOGIC_OP_MODE); newGlobal(t, "GL_LOGIC_OP_MODE");
		pushInt(t, GL_CLEAR); newGlobal(t, "GL_CLEAR");
		pushInt(t, GL_SET); newGlobal(t, "GL_SET");
		pushInt(t, GL_COPY); newGlobal(t, "GL_COPY");
		pushInt(t, GL_COPY_INVERTED); newGlobal(t, "GL_COPY_INVERTED");
		pushInt(t, GL_NOOP); newGlobal(t, "GL_NOOP");
		pushInt(t, GL_INVERT); newGlobal(t, "GL_INVERT");
		pushInt(t, GL_AND); newGlobal(t, "GL_AND");
		pushInt(t, GL_NAND); newGlobal(t, "GL_NAND");
		pushInt(t, GL_OR); newGlobal(t, "GL_OR");
		pushInt(t, GL_NOR); newGlobal(t, "GL_NOR");
		pushInt(t, GL_XOR); newGlobal(t, "GL_XOR");
		pushInt(t, GL_EQUIV); newGlobal(t, "GL_EQUIV");
		pushInt(t, GL_AND_REVERSE); newGlobal(t, "GL_AND_REVERSE");
		pushInt(t, GL_AND_INVERTED); newGlobal(t, "GL_AND_INVERTED");
		pushInt(t, GL_OR_REVERSE); newGlobal(t, "GL_OR_REVERSE");
		pushInt(t, GL_OR_INVERTED); newGlobal(t, "GL_OR_INVERTED");
		pushInt(t, GL_STENCIL_TEST); newGlobal(t, "GL_STENCIL_TEST");
		pushInt(t, GL_STENCIL_WRITEMASK); newGlobal(t, "GL_STENCIL_WRITEMASK");
		pushInt(t, GL_STENCIL_BITS); newGlobal(t, "GL_STENCIL_BITS");
		pushInt(t, GL_STENCIL_FUNC); newGlobal(t, "GL_STENCIL_FUNC");
		pushInt(t, GL_STENCIL_VALUE_MASK); newGlobal(t, "GL_STENCIL_VALUE_MASK");
		pushInt(t, GL_STENCIL_REF); newGlobal(t, "GL_STENCIL_REF");
		pushInt(t, GL_STENCIL_FAIL); newGlobal(t, "GL_STENCIL_FAIL");
		pushInt(t, GL_STENCIL_PASS_DEPTH_PASS); newGlobal(t, "GL_STENCIL_PASS_DEPTH_PASS");
		pushInt(t, GL_STENCIL_PASS_DEPTH_FAIL); newGlobal(t, "GL_STENCIL_PASS_DEPTH_FAIL");
		pushInt(t, GL_STENCIL_CLEAR_VALUE); newGlobal(t, "GL_STENCIL_CLEAR_VALUE");
		pushInt(t, GL_STENCIL_INDEX); newGlobal(t, "GL_STENCIL_INDEX");
		pushInt(t, GL_KEEP); newGlobal(t, "GL_KEEP");
		pushInt(t, GL_REPLACE); newGlobal(t, "GL_REPLACE");
		pushInt(t, GL_INCR); newGlobal(t, "GL_INCR");
		pushInt(t, GL_DECR); newGlobal(t, "GL_DECR");
		pushInt(t, GL_NONE); newGlobal(t, "GL_NONE");
		pushInt(t, GL_LEFT); newGlobal(t, "GL_LEFT");
		pushInt(t, GL_RIGHT); newGlobal(t, "GL_RIGHT");
		pushInt(t, GL_FRONT_LEFT); newGlobal(t, "GL_FRONT_LEFT");
		pushInt(t, GL_FRONT_RIGHT); newGlobal(t, "GL_FRONT_RIGHT");
		pushInt(t, GL_BACK_LEFT); newGlobal(t, "GL_BACK_LEFT");
		pushInt(t, GL_BACK_RIGHT); newGlobal(t, "GL_BACK_RIGHT");
		pushInt(t, GL_AUX0); newGlobal(t, "GL_AUX0");
		pushInt(t, GL_AUX1); newGlobal(t, "GL_AUX1");
		pushInt(t, GL_AUX2); newGlobal(t, "GL_AUX2");
		pushInt(t, GL_AUX3); newGlobal(t, "GL_AUX3");
		pushInt(t, GL_COLOR_INDEX); newGlobal(t, "GL_COLOR_INDEX");
		pushInt(t, GL_RED); newGlobal(t, "GL_RED");
		pushInt(t, GL_GREEN); newGlobal(t, "GL_GREEN");
		pushInt(t, GL_BLUE); newGlobal(t, "GL_BLUE");
		pushInt(t, GL_ALPHA); newGlobal(t, "GL_ALPHA");
		pushInt(t, GL_LUMINANCE); newGlobal(t, "GL_LUMINANCE");
		pushInt(t, GL_LUMINANCE_ALPHA); newGlobal(t, "GL_LUMINANCE_ALPHA");
		pushInt(t, GL_ALPHA_BITS); newGlobal(t, "GL_ALPHA_BITS");
		pushInt(t, GL_RED_BITS); newGlobal(t, "GL_RED_BITS");
		pushInt(t, GL_GREEN_BITS); newGlobal(t, "GL_GREEN_BITS");
		pushInt(t, GL_BLUE_BITS); newGlobal(t, "GL_BLUE_BITS");
		pushInt(t, GL_INDEX_BITS); newGlobal(t, "GL_INDEX_BITS");
		pushInt(t, GL_SUBPIXEL_BITS); newGlobal(t, "GL_SUBPIXEL_BITS");
		pushInt(t, GL_AUX_BUFFERS); newGlobal(t, "GL_AUX_BUFFERS");
		pushInt(t, GL_READ_BUFFER); newGlobal(t, "GL_READ_BUFFER");
		pushInt(t, GL_DRAW_BUFFER); newGlobal(t, "GL_DRAW_BUFFER");
		pushInt(t, GL_DOUBLEBUFFER); newGlobal(t, "GL_DOUBLEBUFFER");
		pushInt(t, GL_STEREO); newGlobal(t, "GL_STEREO");
		pushInt(t, GL_BITMAP); newGlobal(t, "GL_BITMAP");
		pushInt(t, GL_COLOR); newGlobal(t, "GL_COLOR");
		pushInt(t, GL_DEPTH); newGlobal(t, "GL_DEPTH");
		pushInt(t, GL_STENCIL); newGlobal(t, "GL_STENCIL");
		pushInt(t, GL_DITHER); newGlobal(t, "GL_DITHER");
		pushInt(t, GL_RGB); newGlobal(t, "GL_RGB");
		pushInt(t, GL_RGBA); newGlobal(t, "GL_RGBA");
		pushInt(t, GL_MAX_LIST_NESTING); newGlobal(t, "GL_MAX_LIST_NESTING");
		pushInt(t, GL_MAX_ATTRIB_STACK_DEPTH); newGlobal(t, "GL_MAX_ATTRIB_STACK_DEPTH");
		pushInt(t, GL_MAX_MODELVIEW_STACK_DEPTH); newGlobal(t, "GL_MAX_MODELVIEW_STACK_DEPTH");
		pushInt(t, GL_MAX_NAME_STACK_DEPTH); newGlobal(t, "GL_MAX_NAME_STACK_DEPTH");
		pushInt(t, GL_MAX_PROJECTION_STACK_DEPTH); newGlobal(t, "GL_MAX_PROJECTION_STACK_DEPTH");
		pushInt(t, GL_MAX_TEXTURE_STACK_DEPTH); newGlobal(t, "GL_MAX_TEXTURE_STACK_DEPTH");
		pushInt(t, GL_MAX_EVAL_ORDER); newGlobal(t, "GL_MAX_EVAL_ORDER");
		pushInt(t, GL_MAX_LIGHTS); newGlobal(t, "GL_MAX_LIGHTS");
		pushInt(t, GL_MAX_CLIP_PLANES); newGlobal(t, "GL_MAX_CLIP_PLANES");
		pushInt(t, GL_MAX_TEXTURE_SIZE); newGlobal(t, "GL_MAX_TEXTURE_SIZE");
		pushInt(t, GL_MAX_PIXEL_MAP_TABLE); newGlobal(t, "GL_MAX_PIXEL_MAP_TABLE");
		pushInt(t, GL_MAX_VIEWPORT_DIMS); newGlobal(t, "GL_MAX_VIEWPORT_DIMS");
		pushInt(t, GL_MAX_CLIENT_ATTRIB_STACK_DEPTH); newGlobal(t, "GL_MAX_CLIENT_ATTRIB_STACK_DEPTH");
		pushInt(t, GL_ATTRIB_STACK_DEPTH); newGlobal(t, "GL_ATTRIB_STACK_DEPTH");
		pushInt(t, GL_CLIENT_ATTRIB_STACK_DEPTH); newGlobal(t, "GL_CLIENT_ATTRIB_STACK_DEPTH");
		pushInt(t, GL_COLOR_CLEAR_VALUE); newGlobal(t, "GL_COLOR_CLEAR_VALUE");
		pushInt(t, GL_COLOR_WRITEMASK); newGlobal(t, "GL_COLOR_WRITEMASK");
		pushInt(t, GL_CURRENT_INDEX); newGlobal(t, "GL_CURRENT_INDEX");
		pushInt(t, GL_CURRENT_COLOR); newGlobal(t, "GL_CURRENT_COLOR");
		pushInt(t, GL_CURRENT_NORMAL); newGlobal(t, "GL_CURRENT_NORMAL");
		pushInt(t, GL_CURRENT_RASTER_COLOR); newGlobal(t, "GL_CURRENT_RASTER_COLOR");
		pushInt(t, GL_CURRENT_RASTER_DISTANCE); newGlobal(t, "GL_CURRENT_RASTER_DISTANCE");
		pushInt(t, GL_CURRENT_RASTER_INDEX); newGlobal(t, "GL_CURRENT_RASTER_INDEX");
		pushInt(t, GL_CURRENT_RASTER_POSITION); newGlobal(t, "GL_CURRENT_RASTER_POSITION");
		pushInt(t, GL_CURRENT_RASTER_TEXTURE_COORDS); newGlobal(t, "GL_CURRENT_RASTER_TEXTURE_COORDS");
		pushInt(t, GL_CURRENT_RASTER_POSITION_VALID); newGlobal(t, "GL_CURRENT_RASTER_POSITION_VALID");
		pushInt(t, GL_CURRENT_TEXTURE_COORDS); newGlobal(t, "GL_CURRENT_TEXTURE_COORDS");
		pushInt(t, GL_INDEX_CLEAR_VALUE); newGlobal(t, "GL_INDEX_CLEAR_VALUE");
		pushInt(t, GL_INDEX_MODE); newGlobal(t, "GL_INDEX_MODE");
		pushInt(t, GL_INDEX_WRITEMASK); newGlobal(t, "GL_INDEX_WRITEMASK");
		pushInt(t, GL_MODELVIEW_MATRIX); newGlobal(t, "GL_MODELVIEW_MATRIX");
		pushInt(t, GL_MODELVIEW_STACK_DEPTH); newGlobal(t, "GL_MODELVIEW_STACK_DEPTH");
		pushInt(t, GL_NAME_STACK_DEPTH); newGlobal(t, "GL_NAME_STACK_DEPTH");
		pushInt(t, GL_PROJECTION_MATRIX); newGlobal(t, "GL_PROJECTION_MATRIX");
		pushInt(t, GL_PROJECTION_STACK_DEPTH); newGlobal(t, "GL_PROJECTION_STACK_DEPTH");
		pushInt(t, GL_RENDER_MODE); newGlobal(t, "GL_RENDER_MODE");
		pushInt(t, GL_RGBA_MODE); newGlobal(t, "GL_RGBA_MODE");
		pushInt(t, GL_TEXTURE_MATRIX); newGlobal(t, "GL_TEXTURE_MATRIX");
		pushInt(t, GL_TEXTURE_STACK_DEPTH); newGlobal(t, "GL_TEXTURE_STACK_DEPTH");
		pushInt(t, GL_VIEWPORT); newGlobal(t, "GL_VIEWPORT");
		pushInt(t, GL_AUTO_NORMAL); newGlobal(t, "GL_AUTO_NORMAL");
		pushInt(t, GL_MAP1_COLOR_4); newGlobal(t, "GL_MAP1_COLOR_4");
		pushInt(t, GL_MAP1_GRID_DOMAIN); newGlobal(t, "GL_MAP1_GRID_DOMAIN");
		pushInt(t, GL_MAP1_GRID_SEGMENTS); newGlobal(t, "GL_MAP1_GRID_SEGMENTS");
		pushInt(t, GL_MAP1_INDEX); newGlobal(t, "GL_MAP1_INDEX");
		pushInt(t, GL_MAP1_NORMAL); newGlobal(t, "GL_MAP1_NORMAL");
		pushInt(t, GL_MAP1_TEXTURE_COORD_1); newGlobal(t, "GL_MAP1_TEXTURE_COORD_1");
		pushInt(t, GL_MAP1_TEXTURE_COORD_2); newGlobal(t, "GL_MAP1_TEXTURE_COORD_2");
		pushInt(t, GL_MAP1_TEXTURE_COORD_3); newGlobal(t, "GL_MAP1_TEXTURE_COORD_3");
		pushInt(t, GL_MAP1_TEXTURE_COORD_4); newGlobal(t, "GL_MAP1_TEXTURE_COORD_4");
		pushInt(t, GL_MAP1_VERTEX_3); newGlobal(t, "GL_MAP1_VERTEX_3");
		pushInt(t, GL_MAP1_VERTEX_4); newGlobal(t, "GL_MAP1_VERTEX_4");
		pushInt(t, GL_MAP2_COLOR_4); newGlobal(t, "GL_MAP2_COLOR_4");
		pushInt(t, GL_MAP2_GRID_DOMAIN); newGlobal(t, "GL_MAP2_GRID_DOMAIN");
		pushInt(t, GL_MAP2_GRID_SEGMENTS); newGlobal(t, "GL_MAP2_GRID_SEGMENTS");
		pushInt(t, GL_MAP2_INDEX); newGlobal(t, "GL_MAP2_INDEX");
		pushInt(t, GL_MAP2_NORMAL); newGlobal(t, "GL_MAP2_NORMAL");
		pushInt(t, GL_MAP2_TEXTURE_COORD_1); newGlobal(t, "GL_MAP2_TEXTURE_COORD_1");
		pushInt(t, GL_MAP2_TEXTURE_COORD_2); newGlobal(t, "GL_MAP2_TEXTURE_COORD_2");
		pushInt(t, GL_MAP2_TEXTURE_COORD_3); newGlobal(t, "GL_MAP2_TEXTURE_COORD_3");
		pushInt(t, GL_MAP2_TEXTURE_COORD_4); newGlobal(t, "GL_MAP2_TEXTURE_COORD_4");
		pushInt(t, GL_MAP2_VERTEX_3); newGlobal(t, "GL_MAP2_VERTEX_3");
		pushInt(t, GL_MAP2_VERTEX_4); newGlobal(t, "GL_MAP2_VERTEX_4");
		pushInt(t, GL_COEFF); newGlobal(t, "GL_COEFF");
		pushInt(t, GL_DOMAIN); newGlobal(t, "GL_DOMAIN");
		pushInt(t, GL_ORDER); newGlobal(t, "GL_ORDER");
		pushInt(t, GL_FOG_HINT); newGlobal(t, "GL_FOG_HINT");
		pushInt(t, GL_LINE_SMOOTH_HINT); newGlobal(t, "GL_LINE_SMOOTH_HINT");
		pushInt(t, GL_PERSPECTIVE_CORRECTION_HINT); newGlobal(t, "GL_PERSPECTIVE_CORRECTION_HINT");
		pushInt(t, GL_POINT_SMOOTH_HINT); newGlobal(t, "GL_POINT_SMOOTH_HINT");
		pushInt(t, GL_POLYGON_SMOOTH_HINT); newGlobal(t, "GL_POLYGON_SMOOTH_HINT");
		pushInt(t, GL_DONT_CARE); newGlobal(t, "GL_DONT_CARE");
		pushInt(t, GL_FASTEST); newGlobal(t, "GL_FASTEST");
		pushInt(t, GL_NICEST); newGlobal(t, "GL_NICEST");
		pushInt(t, GL_SCISSOR_TEST); newGlobal(t, "GL_SCISSOR_TEST");
		pushInt(t, GL_SCISSOR_BOX); newGlobal(t, "GL_SCISSOR_BOX");
		pushInt(t, GL_MAP_COLOR); newGlobal(t, "GL_MAP_COLOR");
		pushInt(t, GL_MAP_STENCIL); newGlobal(t, "GL_MAP_STENCIL");
		pushInt(t, GL_INDEX_SHIFT); newGlobal(t, "GL_INDEX_SHIFT");
		pushInt(t, GL_INDEX_OFFSET); newGlobal(t, "GL_INDEX_OFFSET");
		pushInt(t, GL_RED_SCALE); newGlobal(t, "GL_RED_SCALE");
		pushInt(t, GL_RED_BIAS); newGlobal(t, "GL_RED_BIAS");
		pushInt(t, GL_GREEN_SCALE); newGlobal(t, "GL_GREEN_SCALE");
		pushInt(t, GL_GREEN_BIAS); newGlobal(t, "GL_GREEN_BIAS");
		pushInt(t, GL_BLUE_SCALE); newGlobal(t, "GL_BLUE_SCALE");
		pushInt(t, GL_BLUE_BIAS); newGlobal(t, "GL_BLUE_BIAS");
		pushInt(t, GL_ALPHA_SCALE); newGlobal(t, "GL_ALPHA_SCALE");
		pushInt(t, GL_ALPHA_BIAS); newGlobal(t, "GL_ALPHA_BIAS");
		pushInt(t, GL_DEPTH_SCALE); newGlobal(t, "GL_DEPTH_SCALE");
		pushInt(t, GL_DEPTH_BIAS); newGlobal(t, "GL_DEPTH_BIAS");
		pushInt(t, GL_PIXEL_MAP_S_TO_S_SIZE); newGlobal(t, "GL_PIXEL_MAP_S_TO_S_SIZE");
		pushInt(t, GL_PIXEL_MAP_I_TO_I_SIZE); newGlobal(t, "GL_PIXEL_MAP_I_TO_I_SIZE");
		pushInt(t, GL_PIXEL_MAP_I_TO_R_SIZE); newGlobal(t, "GL_PIXEL_MAP_I_TO_R_SIZE");
		pushInt(t, GL_PIXEL_MAP_I_TO_G_SIZE); newGlobal(t, "GL_PIXEL_MAP_I_TO_G_SIZE");
		pushInt(t, GL_PIXEL_MAP_I_TO_B_SIZE); newGlobal(t, "GL_PIXEL_MAP_I_TO_B_SIZE");
		pushInt(t, GL_PIXEL_MAP_I_TO_A_SIZE); newGlobal(t, "GL_PIXEL_MAP_I_TO_A_SIZE");
		pushInt(t, GL_PIXEL_MAP_R_TO_R_SIZE); newGlobal(t, "GL_PIXEL_MAP_R_TO_R_SIZE");
		pushInt(t, GL_PIXEL_MAP_G_TO_G_SIZE); newGlobal(t, "GL_PIXEL_MAP_G_TO_G_SIZE");
		pushInt(t, GL_PIXEL_MAP_B_TO_B_SIZE); newGlobal(t, "GL_PIXEL_MAP_B_TO_B_SIZE");
		pushInt(t, GL_PIXEL_MAP_A_TO_A_SIZE); newGlobal(t, "GL_PIXEL_MAP_A_TO_A_SIZE");
		pushInt(t, GL_PIXEL_MAP_S_TO_S); newGlobal(t, "GL_PIXEL_MAP_S_TO_S");
		pushInt(t, GL_PIXEL_MAP_I_TO_I); newGlobal(t, "GL_PIXEL_MAP_I_TO_I");
		pushInt(t, GL_PIXEL_MAP_I_TO_R); newGlobal(t, "GL_PIXEL_MAP_I_TO_R");
		pushInt(t, GL_PIXEL_MAP_I_TO_G); newGlobal(t, "GL_PIXEL_MAP_I_TO_G");
		pushInt(t, GL_PIXEL_MAP_I_TO_B); newGlobal(t, "GL_PIXEL_MAP_I_TO_B");
		pushInt(t, GL_PIXEL_MAP_I_TO_A); newGlobal(t, "GL_PIXEL_MAP_I_TO_A");
		pushInt(t, GL_PIXEL_MAP_R_TO_R); newGlobal(t, "GL_PIXEL_MAP_R_TO_R");
		pushInt(t, GL_PIXEL_MAP_G_TO_G); newGlobal(t, "GL_PIXEL_MAP_G_TO_G");
		pushInt(t, GL_PIXEL_MAP_B_TO_B); newGlobal(t, "GL_PIXEL_MAP_B_TO_B");
		pushInt(t, GL_PIXEL_MAP_A_TO_A); newGlobal(t, "GL_PIXEL_MAP_A_TO_A");
		pushInt(t, GL_PACK_ALIGNMENT); newGlobal(t, "GL_PACK_ALIGNMENT");
		pushInt(t, GL_PACK_LSB_FIRST); newGlobal(t, "GL_PACK_LSB_FIRST");
		pushInt(t, GL_PACK_ROW_LENGTH); newGlobal(t, "GL_PACK_ROW_LENGTH");
		pushInt(t, GL_PACK_SKIP_PIXELS); newGlobal(t, "GL_PACK_SKIP_PIXELS");
		pushInt(t, GL_PACK_SKIP_ROWS); newGlobal(t, "GL_PACK_SKIP_ROWS");
		pushInt(t, GL_PACK_SWAP_BYTES); newGlobal(t, "GL_PACK_SWAP_BYTES");
		pushInt(t, GL_UNPACK_ALIGNMENT); newGlobal(t, "GL_UNPACK_ALIGNMENT");
		pushInt(t, GL_UNPACK_LSB_FIRST); newGlobal(t, "GL_UNPACK_LSB_FIRST");
		pushInt(t, GL_UNPACK_ROW_LENGTH); newGlobal(t, "GL_UNPACK_ROW_LENGTH");
		pushInt(t, GL_UNPACK_SKIP_PIXELS); newGlobal(t, "GL_UNPACK_SKIP_PIXELS");
		pushInt(t, GL_UNPACK_SKIP_ROWS); newGlobal(t, "GL_UNPACK_SKIP_ROWS");
		pushInt(t, GL_UNPACK_SWAP_BYTES); newGlobal(t, "GL_UNPACK_SWAP_BYTES");
		pushInt(t, GL_ZOOM_X); newGlobal(t, "GL_ZOOM_X");
		pushInt(t, GL_ZOOM_Y); newGlobal(t, "GL_ZOOM_Y");
		pushInt(t, GL_TEXTURE_ENV); newGlobal(t, "GL_TEXTURE_ENV");
		pushInt(t, GL_TEXTURE_ENV_MODE); newGlobal(t, "GL_TEXTURE_ENV_MODE");
		pushInt(t, GL_TEXTURE_1D); newGlobal(t, "GL_TEXTURE_1D");
		pushInt(t, GL_TEXTURE_2D); newGlobal(t, "GL_TEXTURE_2D");
		pushInt(t, GL_TEXTURE_WRAP_S); newGlobal(t, "GL_TEXTURE_WRAP_S");
		pushInt(t, GL_TEXTURE_WRAP_T); newGlobal(t, "GL_TEXTURE_WRAP_T");
		pushInt(t, GL_TEXTURE_MAG_FILTER); newGlobal(t, "GL_TEXTURE_MAG_FILTER");
		pushInt(t, GL_TEXTURE_MIN_FILTER); newGlobal(t, "GL_TEXTURE_MIN_FILTER");
		pushInt(t, GL_TEXTURE_ENV_COLOR); newGlobal(t, "GL_TEXTURE_ENV_COLOR");
		pushInt(t, GL_TEXTURE_GEN_S); newGlobal(t, "GL_TEXTURE_GEN_S");
		pushInt(t, GL_TEXTURE_GEN_T); newGlobal(t, "GL_TEXTURE_GEN_T");
		pushInt(t, GL_TEXTURE_GEN_MODE); newGlobal(t, "GL_TEXTURE_GEN_MODE");
		pushInt(t, GL_TEXTURE_BORDER_COLOR); newGlobal(t, "GL_TEXTURE_BORDER_COLOR");
		pushInt(t, GL_TEXTURE_WIDTH); newGlobal(t, "GL_TEXTURE_WIDTH");
		pushInt(t, GL_TEXTURE_HEIGHT); newGlobal(t, "GL_TEXTURE_HEIGHT");
		pushInt(t, GL_TEXTURE_BORDER); newGlobal(t, "GL_TEXTURE_BORDER");
		pushInt(t, GL_TEXTURE_COMPONENTS); newGlobal(t, "GL_TEXTURE_COMPONENTS");
		pushInt(t, GL_TEXTURE_RED_SIZE); newGlobal(t, "GL_TEXTURE_RED_SIZE");
		pushInt(t, GL_TEXTURE_GREEN_SIZE); newGlobal(t, "GL_TEXTURE_GREEN_SIZE");
		pushInt(t, GL_TEXTURE_BLUE_SIZE); newGlobal(t, "GL_TEXTURE_BLUE_SIZE");
		pushInt(t, GL_TEXTURE_ALPHA_SIZE); newGlobal(t, "GL_TEXTURE_ALPHA_SIZE");
		pushInt(t, GL_TEXTURE_LUMINANCE_SIZE); newGlobal(t, "GL_TEXTURE_LUMINANCE_SIZE");
		pushInt(t, GL_TEXTURE_INTENSITY_SIZE); newGlobal(t, "GL_TEXTURE_INTENSITY_SIZE");
		pushInt(t, GL_NEAREST_MIPMAP_NEAREST); newGlobal(t, "GL_NEAREST_MIPMAP_NEAREST");
		pushInt(t, GL_NEAREST_MIPMAP_LINEAR); newGlobal(t, "GL_NEAREST_MIPMAP_LINEAR");
		pushInt(t, GL_LINEAR_MIPMAP_NEAREST); newGlobal(t, "GL_LINEAR_MIPMAP_NEAREST");
		pushInt(t, GL_LINEAR_MIPMAP_LINEAR); newGlobal(t, "GL_LINEAR_MIPMAP_LINEAR");
		pushInt(t, GL_OBJECT_LINEAR); newGlobal(t, "GL_OBJECT_LINEAR");
		pushInt(t, GL_OBJECT_PLANE); newGlobal(t, "GL_OBJECT_PLANE");
		pushInt(t, GL_EYE_LINEAR); newGlobal(t, "GL_EYE_LINEAR");
		pushInt(t, GL_EYE_PLANE); newGlobal(t, "GL_EYE_PLANE");
		pushInt(t, GL_SPHERE_MAP); newGlobal(t, "GL_SPHERE_MAP");
		pushInt(t, GL_DECAL); newGlobal(t, "GL_DECAL");
		pushInt(t, GL_MODULATE); newGlobal(t, "GL_MODULATE");
		pushInt(t, GL_NEAREST); newGlobal(t, "GL_NEAREST");
		pushInt(t, GL_REPEAT); newGlobal(t, "GL_REPEAT");
		pushInt(t, GL_CLAMP); newGlobal(t, "GL_CLAMP");
		pushInt(t, GL_S); newGlobal(t, "GL_S");
		pushInt(t, GL_T); newGlobal(t, "GL_T");
		pushInt(t, GL_R); newGlobal(t, "GL_R");
		pushInt(t, GL_Q); newGlobal(t, "GL_Q");
		pushInt(t, GL_TEXTURE_GEN_R); newGlobal(t, "GL_TEXTURE_GEN_R");
		pushInt(t, GL_TEXTURE_GEN_Q); newGlobal(t, "GL_TEXTURE_GEN_Q");
		pushInt(t, GL_VENDOR); newGlobal(t, "GL_VENDOR");
		pushInt(t, GL_RENDERER); newGlobal(t, "GL_RENDERER");
		pushInt(t, GL_VERSION); newGlobal(t, "GL_VERSION");
		pushInt(t, GL_EXTENSIONS); newGlobal(t, "GL_EXTENSIONS");
		pushInt(t, GL_NO_ERROR); newGlobal(t, "GL_NO_ERROR");
		pushInt(t, GL_INVALID_VALUE); newGlobal(t, "GL_INVALID_VALUE");
		pushInt(t, GL_INVALID_ENUM); newGlobal(t, "GL_INVALID_ENUM");
		pushInt(t, GL_INVALID_OPERATION); newGlobal(t, "GL_INVALID_OPERATION");
		pushInt(t, GL_STACK_OVERFLOW); newGlobal(t, "GL_STACK_OVERFLOW");
		pushInt(t, GL_STACK_UNDERFLOW); newGlobal(t, "GL_STACK_UNDERFLOW");
		pushInt(t, GL_OUT_OF_MEMORY); newGlobal(t, "GL_OUT_OF_MEMORY");
		pushInt(t, GL_CURRENT_BIT); newGlobal(t, "GL_CURRENT_BIT");
		pushInt(t, GL_POINT_BIT); newGlobal(t, "GL_POINT_BIT");
		pushInt(t, GL_LINE_BIT); newGlobal(t, "GL_LINE_BIT");
		pushInt(t, GL_POLYGON_BIT); newGlobal(t, "GL_POLYGON_BIT");
		pushInt(t, GL_POLYGON_STIPPLE_BIT); newGlobal(t, "GL_POLYGON_STIPPLE_BIT");
		pushInt(t, GL_PIXEL_MODE_BIT); newGlobal(t, "GL_PIXEL_MODE_BIT");
		pushInt(t, GL_LIGHTING_BIT); newGlobal(t, "GL_LIGHTING_BIT");
		pushInt(t, GL_FOG_BIT); newGlobal(t, "GL_FOG_BIT");
		pushInt(t, GL_DEPTH_BUFFER_BIT); newGlobal(t, "GL_DEPTH_BUFFER_BIT");
		pushInt(t, GL_ACCUM_BUFFER_BIT); newGlobal(t, "GL_ACCUM_BUFFER_BIT");
		pushInt(t, GL_STENCIL_BUFFER_BIT); newGlobal(t, "GL_STENCIL_BUFFER_BIT");
		pushInt(t, GL_VIEWPORT_BIT); newGlobal(t, "GL_VIEWPORT_BIT");
		pushInt(t, GL_TRANSFORM_BIT); newGlobal(t, "GL_TRANSFORM_BIT");
		pushInt(t, GL_ENABLE_BIT); newGlobal(t, "GL_ENABLE_BIT");
		pushInt(t, GL_COLOR_BUFFER_BIT); newGlobal(t, "GL_COLOR_BUFFER_BIT");
		pushInt(t, GL_HINT_BIT); newGlobal(t, "GL_HINT_BIT");
		pushInt(t, GL_EVAL_BIT); newGlobal(t, "GL_EVAL_BIT");
		pushInt(t, GL_LIST_BIT); newGlobal(t, "GL_LIST_BIT");
		pushInt(t, GL_TEXTURE_BIT); newGlobal(t, "GL_TEXTURE_BIT");
		pushInt(t, GL_SCISSOR_BIT); newGlobal(t, "GL_SCISSOR_BIT");
		pushInt(t, GL_ALL_ATTRIB_BITS); newGlobal(t, "GL_ALL_ATTRIB_BITS");

		// gl 1.1
		register(t, &wrapGL!(glGenTextures), "glGenTextures");
		register(t, &wrapGL!(glDeleteTextures), "glDeleteTextures");
		register(t, &wrapGL!(glBindTexture), "glBindTexture");
		register(t, &wrapGL!(glPrioritizeTextures), "glPrioritizeTextures");
		register(t, &wrapGL!(glAreTexturesResident), "glAreTexturesResident");
		register(t, &wrapGL!(glIsTexture), "glIsTexture");
		register(t, &wrapGL!(glTexSubImage1D), "glTexSubImage1D");
		register(t, &wrapGL!(glTexSubImage2D), "glTexSubImage2D");
		register(t, &wrapGL!(glCopyTexImage1D), "glCopyTexImage1D");
		register(t, &wrapGL!(glCopyTexImage2D), "glCopyTexImage2D");
		register(t, &wrapGL!(glCopyTexSubImage1D), "glCopyTexSubImage1D");
		register(t, &wrapGL!(glCopyTexSubImage2D), "glCopyTexSubImage2D");
		register(t, &wrapGL!(glVertexPointer), "glVertexPointer");
		register(t, &wrapGL!(glNormalPointer), "glNormalPointer");
		register(t, &wrapGL!(glColorPointer), "glColorPointer");
		register(t, &wrapGL!(glIndexPointer), "glIndexPointer");
		register(t, &wrapGL!(glTexCoordPointer), "glTexCoordPointer");
		register(t, &wrapGL!(glEdgeFlagPointer), "glEdgeFlagPointer");
// 		register(t, &wrapGL!(glGetPointerv), "glGetPointerv");
		register(t, &wrapGL!(glArrayElement), "glArrayElement");
		register(t, &wrapGL!(glDrawArrays), "glDrawArrays");
		register(t, &wrapGL!(glDrawElements), "glDrawElements");
		register(t, &wrapGL!(glInterleavedArrays), "glInterleavedArrays");

		pushInt(t, GL_PROXY_TEXTURE_1D); newGlobal(t, "GL_PROXY_TEXTURE_1D");
		pushInt(t, GL_PROXY_TEXTURE_2D); newGlobal(t, "GL_PROXY_TEXTURE_2D");
		pushInt(t, GL_TEXTURE_PRIORITY); newGlobal(t, "GL_TEXTURE_PRIORITY");
		pushInt(t, GL_TEXTURE_RESIDENT); newGlobal(t, "GL_TEXTURE_RESIDENT");
		pushInt(t, GL_TEXTURE_BINDING_1D); newGlobal(t, "GL_TEXTURE_BINDING_1D");
		pushInt(t, GL_TEXTURE_BINDING_2D); newGlobal(t, "GL_TEXTURE_BINDING_2D");
		pushInt(t, GL_TEXTURE_INTERNAL_FORMAT); newGlobal(t, "GL_TEXTURE_INTERNAL_FORMAT");
		pushInt(t, GL_ALPHA4); newGlobal(t, "GL_ALPHA4");
		pushInt(t, GL_ALPHA8); newGlobal(t, "GL_ALPHA8");
		pushInt(t, GL_ALPHA12); newGlobal(t, "GL_ALPHA12");
		pushInt(t, GL_ALPHA16); newGlobal(t, "GL_ALPHA16");
		pushInt(t, GL_LUMINANCE4); newGlobal(t, "GL_LUMINANCE4");
		pushInt(t, GL_LUMINANCE8); newGlobal(t, "GL_LUMINANCE8");
		pushInt(t, GL_LUMINANCE12); newGlobal(t, "GL_LUMINANCE12");
		pushInt(t, GL_LUMINANCE16); newGlobal(t, "GL_LUMINANCE16");
		pushInt(t, GL_LUMINANCE4_ALPHA4); newGlobal(t, "GL_LUMINANCE4_ALPHA4");
		pushInt(t, GL_LUMINANCE6_ALPHA2); newGlobal(t, "GL_LUMINANCE6_ALPHA2");
		pushInt(t, GL_LUMINANCE8_ALPHA8); newGlobal(t, "GL_LUMINANCE8_ALPHA8");
		pushInt(t, GL_LUMINANCE12_ALPHA4); newGlobal(t, "GL_LUMINANCE12_ALPHA4");
		pushInt(t, GL_LUMINANCE12_ALPHA12); newGlobal(t, "GL_LUMINANCE12_ALPHA12");
		pushInt(t, GL_LUMINANCE16_ALPHA16); newGlobal(t, "GL_LUMINANCE16_ALPHA16");
		pushInt(t, GL_INTENSITY); newGlobal(t, "GL_INTENSITY");
		pushInt(t, GL_INTENSITY4); newGlobal(t, "GL_INTENSITY4");
		pushInt(t, GL_INTENSITY8); newGlobal(t, "GL_INTENSITY8");
		pushInt(t, GL_INTENSITY12); newGlobal(t, "GL_INTENSITY12");
		pushInt(t, GL_INTENSITY16); newGlobal(t, "GL_INTENSITY16");
		pushInt(t, GL_R3_G3_B2); newGlobal(t, "GL_R3_G3_B2");
		pushInt(t, GL_RGB4); newGlobal(t, "GL_RGB4");
		pushInt(t, GL_RGB5); newGlobal(t, "GL_RGB5");
		pushInt(t, GL_RGB8); newGlobal(t, "GL_RGB8");
		pushInt(t, GL_RGB10); newGlobal(t, "GL_RGB10");
		pushInt(t, GL_RGB12); newGlobal(t, "GL_RGB12");
		pushInt(t, GL_RGB16); newGlobal(t, "GL_RGB16");
		pushInt(t, GL_RGBA2); newGlobal(t, "GL_RGBA2");
		pushInt(t, GL_RGBA4); newGlobal(t, "GL_RGBA4");
		pushInt(t, GL_RGB5_A1); newGlobal(t, "GL_RGB5_A1");
		pushInt(t, GL_RGBA8); newGlobal(t, "GL_RGBA8");
		pushInt(t, GL_RGB10_A2); newGlobal(t, "GL_RGB10_A2");
		pushInt(t, GL_RGBA12); newGlobal(t, "GL_RGBA12");
		pushInt(t, GL_RGBA16); newGlobal(t, "GL_RGBA16");
		pushInt(t, GL_CLIENT_PIXEL_STORE_BIT); newGlobal(t, "GL_CLIENT_PIXEL_STORE_BIT");
		pushInt(t, GL_CLIENT_VERTEX_ARRAY_BIT); newGlobal(t, "GL_CLIENT_VERTEX_ARRAY_BIT");
		pushInt(t, GL_ALL_CLIENT_ATTRIB_BITS); newGlobal(t, "GL_ALL_CLIENT_ATTRIB_BITS");
		pushInt(t, GL_CLIENT_ALL_ATTRIB_BITS); newGlobal(t, "GL_CLIENT_ALL_ATTRIB_BITS");

	// those with comment indentation levels here are not bound by derelict by default

		// glu
	//	register(t, &wrapGL!(gluBuild1DMipmapLevels), "gluBuild1DMipmapLevels");
		register(t, &wrapGL!(gluBuild1DMipmaps), "gluBuild1DMipmaps");
	//	register(t, &wrapGL!(gluBuild2DMipmapLevels), "gluBuild2DMipmapLevels");
		register(t, &wrapGL!(gluBuild2DMipmaps), "gluBuild2DMipmaps");
	//	register(t, &wrapGL!(gluBuild3DMipmapLevels), "gluBuild3DMipmapLevels");
	//	register(t, &wrapGL!(gluBuild3DMipmaps), "gluBuild3DMipmaps");
	//	register(t, &wrapGL!(gluCheckExtension), "gluCheckExtension");
		register(t, &crocgluErrorString, "gluErrorString");
		register(t, &crocgluGetString, "gluGetString");
// 		register(t, &wrapGL!(gluCylinder), "gluCylinder");
// 		register(t, &wrapGL!(gluDisk), "gluDisk");
// 		register(t, &wrapGL!(gluPartialDisk), "gluPartialDisk");
// 		register(t, &wrapGL!(gluSphere), "gluSphere");
// 		register(t, &wrapGL!(gluBeginCurve), "gluBeginCurve");
// 		register(t, &wrapGL!(gluBeginPolygon), "gluBeginPolygon");
// 		register(t, &wrapGL!(gluBeginSurface), "gluBeginSurface");
// 		register(t, &wrapGL!(gluBeginTrim), "gluBeginTrim");
// 		register(t, &wrapGL!(gluEndCurve), "gluEndCurve");
// 		register(t, &wrapGL!(gluEndPolygon), "gluEndPolygon");
// 		register(t, &wrapGL!(gluEndSurface), "gluEndSurface");
// 		register(t, &wrapGL!(gluEndTrim), "gluEndTrim");
// 		register(t, &wrapGL!(gluDeleteNurbsRenderer), "gluDeleteNurbsRenderer");
// 		register(t, &wrapGL!(gluDeleteQuadric), "gluDeleteQuadric");
// 		register(t, &wrapGL!(gluDeleteTess), "gluDeleteTess");
// 		register(t, &wrapGL!(gluGetNurbsProperty), "gluGetNurbsProperty");
// 		register(t, &wrapGL!(gluGetTessProperty), "gluGetTessProperty");
// 		register(t, &wrapGL!(gluLoadSamplingMatrices), "gluLoadSamplingMatrices");
// 		register(t, &wrapGL!(gluNewNurbsRenderer), "gluNewNurbsRenderer");
// 		register(t, &wrapGL!(gluNewQuadric), "gluNewQuadric");
// 		register(t, &wrapGL!(gluNewTess), "gluNewTess");
// 		register(t, &wrapGL!(gluNextContour), "gluNextContour");
// 		register(t, &wrapGL!(gluNurbsCallback), "gluNurbsCallback");
	//	register(t, &wrapGL!(gluNurbsCallbackData), "gluNurbsCallbackData");
	//	register(t, &wrapGL!(gluNurbsCallbackDataEXT), "gluNurbsCallbackDataEXT");
// 		register(t, &wrapGL!(gluNurbsCurve), "gluNurbsCurve");
// 		register(t, &wrapGL!(gluNurbsProperty), "gluNurbsProperty");
// 		register(t, &wrapGL!(gluNurbsSurface), "gluNurbsSurface");
// 		register(t, &wrapGL!(gluPwlCurve), "gluPwlCurve");
// 		register(t, &wrapGL!(gluQuadricCallback), "gluQuadricCallback");
// 		register(t, &wrapGL!(gluQuadricDrawStyle), "gluQuadricDrawStyle");
// 		register(t, &wrapGL!(gluQuadricNormals), "gluQuadricNormals");
// 		register(t, &wrapGL!(gluQuadricOrientation), "gluQuadricOrientation");
// 		register(t, &wrapGL!(gluQuadricTexture), "gluQuadricTexture");
// 		register(t, &wrapGL!(gluTessBeginContour), "gluTessBeginContour");
// 		register(t, &wrapGL!(gluTessBeginPolygon), "gluTessBeginPolygon");
// 		register(t, &wrapGL!(gluTessCallback), "gluTessCallback");
// 		register(t, &wrapGL!(gluTessEndContour), "gluTessEndContour");
// 		register(t, &wrapGL!(gluTessEndPolygon), "gluTessEndPolygon");
// 		register(t, &wrapGL!(gluTessNormal), "gluTessNormal");
// 		register(t, &wrapGL!(gluTessProperty), "gluTessProperty");
// 		register(t, &wrapGL!(gluTessVertex), "gluTessVertex");
		register(t, &wrapGL!(gluLookAt), "gluLookAt");
		register(t, &wrapGL!(gluOrtho2D), "gluOrtho2D");
		register(t, &wrapGL!(gluPerspective), "gluPerspective");
		register(t, &wrapGL!(gluPickMatrix), "gluPickMatrix");
		register(t, &wrapGL!(gluProject), "gluProject");
		register(t, &wrapGL!(gluScaleImage), "gluScaleImage");
		register(t, &wrapGL!(gluUnProject), "gluUnProject");
	//	register(t, &wrapGL!(gluUnProject4), "gluUnProject4");
	
		pushInt(t, GLU_VERSION); newGlobal(t, "GLU_VERSION");
		pushInt(t, GLU_EXTENSIONS); newGlobal(t, "GLU_EXTENSIONS");
		pushInt(t, GLU_INVALID_ENUM); newGlobal(t, "GLU_INVALID_ENUM");
		pushInt(t, GLU_INVALID_VALUE); newGlobal(t, "GLU_INVALID_VALUE");
		pushInt(t, GLU_OUT_OF_MEMORY); newGlobal(t, "GLU_OUT_OF_MEMORY");
		pushInt(t, GLU_INVALID_OPERATION); newGlobal(t, "GLU_INVALID_OPERATION");
		pushInt(t, GLU_OUTLINE_POLYGON); newGlobal(t, "GLU_OUTLINE_POLYGON");
		pushInt(t, GLU_OUTLINE_PATCH); newGlobal(t, "GLU_OUTLINE_PATCH");
		pushInt(t, GLU_NURBS_ERROR); newGlobal(t, "GLU_NURBS_ERROR");
		pushInt(t, GLU_ERROR); newGlobal(t, "GLU_ERROR");
		pushInt(t, GLU_NURBS_BEGIN); newGlobal(t, "GLU_NURBS_BEGIN");
		pushInt(t, GLU_NURBS_BEGIN_EXT); newGlobal(t, "GLU_NURBS_BEGIN_EXT");
		pushInt(t, GLU_NURBS_VERTEX); newGlobal(t, "GLU_NURBS_VERTEX");
		pushInt(t, GLU_NURBS_VERTEX_EXT); newGlobal(t, "GLU_NURBS_VERTEX_EXT");
		pushInt(t, GLU_NURBS_NORMAL); newGlobal(t, "GLU_NURBS_NORMAL");
		pushInt(t, GLU_NURBS_NORMAL_EXT); newGlobal(t, "GLU_NURBS_NORMAL_EXT");
		pushInt(t, GLU_NURBS_COLOR); newGlobal(t, "GLU_NURBS_COLOR");
		pushInt(t, GLU_NURBS_COLOR_EXT); newGlobal(t, "GLU_NURBS_COLOR_EXT");
		pushInt(t, GLU_NURBS_TEXTURE_COORD); newGlobal(t, "GLU_NURBS_TEXTURE_COORD");
		pushInt(t, GLU_NURBS_TEX_COORD_EXT); newGlobal(t, "GLU_NURBS_TEX_COORD_EXT");
		pushInt(t, GLU_NURBS_END); newGlobal(t, "GLU_NURBS_END");
		pushInt(t, GLU_NURBS_END_EXT); newGlobal(t, "GLU_NURBS_END_EXT");
		pushInt(t, GLU_NURBS_BEGIN_DATA); newGlobal(t, "GLU_NURBS_BEGIN_DATA");
		pushInt(t, GLU_NURBS_BEGIN_DATA_EXT); newGlobal(t, "GLU_NURBS_BEGIN_DATA_EXT");
		pushInt(t, GLU_NURBS_VERTEX_DATA); newGlobal(t, "GLU_NURBS_VERTEX_DATA");
		pushInt(t, GLU_NURBS_VERTEX_DATA_EXT); newGlobal(t, "GLU_NURBS_VERTEX_DATA_EXT");
		pushInt(t, GLU_NURBS_NORMAL_DATA); newGlobal(t, "GLU_NURBS_NORMAL_DATA");
		pushInt(t, GLU_NURBS_NORMAL_DATA_EXT); newGlobal(t, "GLU_NURBS_NORMAL_DATA_EXT");
		pushInt(t, GLU_NURBS_COLOR_DATA); newGlobal(t, "GLU_NURBS_COLOR_DATA");
		pushInt(t, GLU_NURBS_COLOR_DATA_EXT); newGlobal(t, "GLU_NURBS_COLOR_DATA_EXT");
		pushInt(t, GLU_NURBS_TEXTURE_COORD_DATA); newGlobal(t, "GLU_NURBS_TEXTURE_COORD_DATA");
		pushInt(t, GLU_NURBS_TEX_COORD_DATA_EXT); newGlobal(t, "GLU_NURBS_TEX_COORD_DATA_EXT");
		pushInt(t, GLU_NURBS_END_DATA); newGlobal(t, "GLU_NURBS_END_DATA");
		pushInt(t, GLU_NURBS_END_DATA_EXT); newGlobal(t, "GLU_NURBS_END_DATA_EXT");
		pushInt(t, GLU_NURBS_ERROR1); newGlobal(t, "GLU_NURBS_ERROR1");
		pushInt(t, GLU_NURBS_ERROR2); newGlobal(t, "GLU_NURBS_ERROR2");
		pushInt(t, GLU_NURBS_ERROR3); newGlobal(t, "GLU_NURBS_ERROR3");
		pushInt(t, GLU_NURBS_ERROR4); newGlobal(t, "GLU_NURBS_ERROR4");
		pushInt(t, GLU_NURBS_ERROR5); newGlobal(t, "GLU_NURBS_ERROR5");
		pushInt(t, GLU_NURBS_ERROR6); newGlobal(t, "GLU_NURBS_ERROR6");
		pushInt(t, GLU_NURBS_ERROR7); newGlobal(t, "GLU_NURBS_ERROR7");
		pushInt(t, GLU_NURBS_ERROR8); newGlobal(t, "GLU_NURBS_ERROR8");
		pushInt(t, GLU_NURBS_ERROR9); newGlobal(t, "GLU_NURBS_ERROR9");
		pushInt(t, GLU_NURBS_ERROR10); newGlobal(t, "GLU_NURBS_ERROR10");
		pushInt(t, GLU_NURBS_ERROR11); newGlobal(t, "GLU_NURBS_ERROR11");
		pushInt(t, GLU_NURBS_ERROR12); newGlobal(t, "GLU_NURBS_ERROR12");
		pushInt(t, GLU_NURBS_ERROR13); newGlobal(t, "GLU_NURBS_ERROR13");
		pushInt(t, GLU_NURBS_ERROR14); newGlobal(t, "GLU_NURBS_ERROR14");
		pushInt(t, GLU_NURBS_ERROR15); newGlobal(t, "GLU_NURBS_ERROR15");
		pushInt(t, GLU_NURBS_ERROR16); newGlobal(t, "GLU_NURBS_ERROR16");
		pushInt(t, GLU_NURBS_ERROR17); newGlobal(t, "GLU_NURBS_ERROR17");
		pushInt(t, GLU_NURBS_ERROR18); newGlobal(t, "GLU_NURBS_ERROR18");
		pushInt(t, GLU_NURBS_ERROR19); newGlobal(t, "GLU_NURBS_ERROR19");
		pushInt(t, GLU_NURBS_ERROR20); newGlobal(t, "GLU_NURBS_ERROR20");
		pushInt(t, GLU_NURBS_ERROR21); newGlobal(t, "GLU_NURBS_ERROR21");
		pushInt(t, GLU_NURBS_ERROR22); newGlobal(t, "GLU_NURBS_ERROR22");
		pushInt(t, GLU_NURBS_ERROR23); newGlobal(t, "GLU_NURBS_ERROR23");
		pushInt(t, GLU_NURBS_ERROR24); newGlobal(t, "GLU_NURBS_ERROR24");
		pushInt(t, GLU_NURBS_ERROR25); newGlobal(t, "GLU_NURBS_ERROR25");
		pushInt(t, GLU_NURBS_ERROR26); newGlobal(t, "GLU_NURBS_ERROR26");
		pushInt(t, GLU_NURBS_ERROR27); newGlobal(t, "GLU_NURBS_ERROR27");
		pushInt(t, GLU_NURBS_ERROR28); newGlobal(t, "GLU_NURBS_ERROR28");
		pushInt(t, GLU_NURBS_ERROR29); newGlobal(t, "GLU_NURBS_ERROR29");
		pushInt(t, GLU_NURBS_ERROR30); newGlobal(t, "GLU_NURBS_ERROR30");
		pushInt(t, GLU_NURBS_ERROR31); newGlobal(t, "GLU_NURBS_ERROR31");
		pushInt(t, GLU_NURBS_ERROR32); newGlobal(t, "GLU_NURBS_ERROR32");
		pushInt(t, GLU_NURBS_ERROR33); newGlobal(t, "GLU_NURBS_ERROR33");
		pushInt(t, GLU_NURBS_ERROR34); newGlobal(t, "GLU_NURBS_ERROR34");
		pushInt(t, GLU_NURBS_ERROR35); newGlobal(t, "GLU_NURBS_ERROR35");
		pushInt(t, GLU_NURBS_ERROR36); newGlobal(t, "GLU_NURBS_ERROR36");
		pushInt(t, GLU_NURBS_ERROR37); newGlobal(t, "GLU_NURBS_ERROR37");
		pushInt(t, GLU_AUTO_LOAD_MATRIX); newGlobal(t, "GLU_AUTO_LOAD_MATRIX");
		pushInt(t, GLU_CULLING); newGlobal(t, "GLU_CULLING");
		pushInt(t, GLU_SAMPLING_TOLERANCE); newGlobal(t, "GLU_SAMPLING_TOLERANCE");
		pushInt(t, GLU_DISPLAY_MODE); newGlobal(t, "GLU_DISPLAY_MODE");
		pushInt(t, GLU_PARAMETRIC_TOLERANCE); newGlobal(t, "GLU_PARAMETRIC_TOLERANCE");
		pushInt(t, GLU_SAMPLING_METHOD); newGlobal(t, "GLU_SAMPLING_METHOD");
		pushInt(t, GLU_U_STEP); newGlobal(t, "GLU_U_STEP");
		pushInt(t, GLU_V_STEP); newGlobal(t, "GLU_V_STEP");
		pushInt(t, GLU_NURBS_MODE); newGlobal(t, "GLU_NURBS_MODE");
		pushInt(t, GLU_NURBS_MODE_EXT); newGlobal(t, "GLU_NURBS_MODE_EXT");
		pushInt(t, GLU_NURBS_TESSELLATOR); newGlobal(t, "GLU_NURBS_TESSELLATOR");
		pushInt(t, GLU_NURBS_TESSELLATOR_EXT); newGlobal(t, "GLU_NURBS_TESSELLATOR_EXT");
		pushInt(t, GLU_NURBS_RENDERER); newGlobal(t, "GLU_NURBS_RENDERER");
		pushInt(t, GLU_NURBS_RENDERER_EXT); newGlobal(t, "GLU_NURBS_RENDERER_EXT");
		pushInt(t, GLU_OBJECT_PARAMETRIC_ERROR); newGlobal(t, "GLU_OBJECT_PARAMETRIC_ERROR");
		pushInt(t, GLU_OBJECT_PARAMETRIC_ERROR_EXT); newGlobal(t, "GLU_OBJECT_PARAMETRIC_ERROR_EXT");
		pushInt(t, GLU_OBJECT_PATH_LENGTH); newGlobal(t, "GLU_OBJECT_PATH_LENGTH");
		pushInt(t, GLU_OBJECT_PATH_LENGTH_EXT); newGlobal(t, "GLU_OBJECT_PATH_LENGTH_EXT");
		pushInt(t, GLU_PATH_LENGTH); newGlobal(t, "GLU_PATH_LENGTH");
		pushInt(t, GLU_PARAMETRIC_ERROR); newGlobal(t, "GLU_PARAMETRIC_ERROR");
		pushInt(t, GLU_DOMAIN_DISTANCE); newGlobal(t, "GLU_DOMAIN_DISTANCE");
		pushInt(t, GLU_MAP1_TRIM_2); newGlobal(t, "GLU_MAP1_TRIM_2");
		pushInt(t, GLU_MAP2_TRIM_3); newGlobal(t, "GLU_MAP2_TRIM_3");
		pushInt(t, GLU_POINT); newGlobal(t, "GLU_POINT");
		pushInt(t, GLU_LINE); newGlobal(t, "GLU_LINE");
		pushInt(t, GLU_FILL); newGlobal(t, "GLU_FILL");
		pushInt(t, GLU_SILHOUETTE); newGlobal(t, "GLU_SILHOUETTE");
		pushInt(t, GLU_SMOOTH); newGlobal(t, "GLU_SMOOTH");
		pushInt(t, GLU_FLAT); newGlobal(t, "GLU_FLAT");
		pushInt(t, GLU_NONE); newGlobal(t, "GLU_NONE");
		pushInt(t, GLU_OUTSIDE); newGlobal(t, "GLU_OUTSIDE");
		pushInt(t, GLU_INSIDE); newGlobal(t, "GLU_INSIDE");
		pushInt(t, GLU_TESS_BEGIN); newGlobal(t, "GLU_TESS_BEGIN");
		pushInt(t, GLU_BEGIN); newGlobal(t, "GLU_BEGIN");
		pushInt(t, GLU_TESS_VERTEX); newGlobal(t, "GLU_TESS_VERTEX");
		pushInt(t, GLU_VERTEX); newGlobal(t, "GLU_VERTEX");
		pushInt(t, GLU_TESS_END); newGlobal(t, "GLU_TESS_END");
		pushInt(t, GLU_END); newGlobal(t, "GLU_END");
		pushInt(t, GLU_TESS_ERROR); newGlobal(t, "GLU_TESS_ERROR");
		pushInt(t, GLU_TESS_EDGE_FLAG); newGlobal(t, "GLU_TESS_EDGE_FLAG");
		pushInt(t, GLU_EDGE_FLAG); newGlobal(t, "GLU_EDGE_FLAG");
		pushInt(t, GLU_TESS_COMBINE); newGlobal(t, "GLU_TESS_COMBINE");
		pushInt(t, GLU_TESS_BEGIN_DATA); newGlobal(t, "GLU_TESS_BEGIN_DATA");
		pushInt(t, GLU_TESS_VERTEX_DATA); newGlobal(t, "GLU_TESS_VERTEX_DATA");
		pushInt(t, GLU_TESS_END_DATA); newGlobal(t, "GLU_TESS_END_DATA");
		pushInt(t, GLU_TESS_ERROR_DATA); newGlobal(t, "GLU_TESS_ERROR_DATA");
		pushInt(t, GLU_TESS_EDGE_FLAG_DATA); newGlobal(t, "GLU_TESS_EDGE_FLAG_DATA");
		pushInt(t, GLU_TESS_COMBINE_DATA); newGlobal(t, "GLU_TESS_COMBINE_DATA");
		pushInt(t, GLU_CW); newGlobal(t, "GLU_CW");
		pushInt(t, GLU_CCW); newGlobal(t, "GLU_CCW");
		pushInt(t, GLU_INTERIOR); newGlobal(t, "GLU_INTERIOR");
		pushInt(t, GLU_EXTERIOR); newGlobal(t, "GLU_EXTERIOR");
		pushInt(t, GLU_UNKNOWN); newGlobal(t, "GLU_UNKNOWN");
		pushInt(t, GLU_TESS_WINDING_RULE); newGlobal(t, "GLU_TESS_WINDING_RULE");
		pushInt(t, GLU_TESS_BOUNDARY_ONLY); newGlobal(t, "GLU_TESS_BOUNDARY_ONLY");
		pushInt(t, GLU_TESS_TOLERANCE); newGlobal(t, "GLU_TESS_TOLERANCE");
		pushInt(t, GLU_TESS_ERROR1); newGlobal(t, "GLU_TESS_ERROR1");
		pushInt(t, GLU_TESS_ERROR2); newGlobal(t, "GLU_TESS_ERROR2");
		pushInt(t, GLU_TESS_ERROR3); newGlobal(t, "GLU_TESS_ERROR3");
		pushInt(t, GLU_TESS_ERROR4); newGlobal(t, "GLU_TESS_ERROR4");
		pushInt(t, GLU_TESS_ERROR5); newGlobal(t, "GLU_TESS_ERROR5");
		pushInt(t, GLU_TESS_ERROR6); newGlobal(t, "GLU_TESS_ERROR6");
		pushInt(t, GLU_TESS_ERROR7); newGlobal(t, "GLU_TESS_ERROR7");
		pushInt(t, GLU_TESS_ERROR8); newGlobal(t, "GLU_TESS_ERROR8");
		pushInt(t, GLU_TESS_MISSING_BEGIN_POLYGON); newGlobal(t, "GLU_TESS_MISSING_BEGIN_POLYGON");
		pushInt(t, GLU_TESS_MISSING_BEGIN_COUNTER); newGlobal(t, "GLU_TESS_MISSING_BEGIN_COUNTER");
		pushInt(t, GLU_TESS_MISSING_END_POLYGON); newGlobal(t, "GLU_TESS_MISSING_END_POLYGON");
		pushInt(t, GLU_TESS_MISSING_END_COUNTER); newGlobal(t, "GLU_TESS_MISSING_END_COUNTER");
		pushInt(t, GLU_TESS_COORD_TOO_LARGE); newGlobal(t, "GLU_TESS_COORD_TOO_LARGE");
		pushInt(t, GLU_TESS_NEED_COMBINE_CALLBACK); newGlobal(t, "GLU_TESS_NEED_COMBINE_CALLBACK");
		pushInt(t, GLU_TESS_WINDING_ODD); newGlobal(t, "GLU_TESS_WINDING_ODD");
		pushInt(t, GLU_TESS_WINDING_NONZERO); newGlobal(t, "GLU_TESS_WINDING_NONZERO");
		pushInt(t, GLU_TESS_WINDING_POSITIVE); newGlobal(t, "GLU_TESS_WINDING_POSITIVE");
		pushInt(t, GLU_TESS_WINDING_NEGATIVE); newGlobal(t, "GLU_TESS_WINDING_NEGATIVE");
		pushInt(t, GLU_TESS_WINDING_ABS_GEQ_TWO); newGlobal(t, "GLU_TESS_WINDING_ABS_GEQ_TWO");
		pushFloat(t, GLU_TESS_MAX_COORD); newGlobal(t, "GLU_TESS_MAX_COORD");
	}

	void loadGL12(CrocThread* t)
	{
		register(t, &wrapGL!(glDrawRangeElements), "glDrawRangeElements");
		register(t, &wrapGL!(glTexImage3D), "glTexImage3D");
		register(t, &wrapGL!(glTexSubImage3D), "glTexSubImage3D");
		register(t, &wrapGL!(glCopyTexSubImage3D), "glCopyTexSubImage3D");

		pushInt(t, GL_RESCALE_NORMAL); newGlobal(t, "GL_RESCALE_NORMAL");
		pushInt(t, GL_CLAMP_TO_EDGE); newGlobal(t, "GL_CLAMP_TO_EDGE");
		pushInt(t, GL_MAX_ELEMENTS_VERTICES); newGlobal(t, "GL_MAX_ELEMENTS_VERTICES");
		pushInt(t, GL_MAX_ELEMENTS_INDICES); newGlobal(t, "GL_MAX_ELEMENTS_INDICES");
		pushInt(t, GL_BGR); newGlobal(t, "GL_BGR");
		pushInt(t, GL_BGRA); newGlobal(t, "GL_BGRA");
		pushInt(t, GL_UNSIGNED_BYTE_3_3_2); newGlobal(t, "GL_UNSIGNED_BYTE_3_3_2");
		pushInt(t, GL_UNSIGNED_BYTE_2_3_3_REV); newGlobal(t, "GL_UNSIGNED_BYTE_2_3_3_REV");
		pushInt(t, GL_UNSIGNED_SHORT_5_6_5); newGlobal(t, "GL_UNSIGNED_SHORT_5_6_5");
		pushInt(t, GL_UNSIGNED_SHORT_5_6_5_REV); newGlobal(t, "GL_UNSIGNED_SHORT_5_6_5_REV");
		pushInt(t, GL_UNSIGNED_SHORT_4_4_4_4); newGlobal(t, "GL_UNSIGNED_SHORT_4_4_4_4");
		pushInt(t, GL_UNSIGNED_SHORT_4_4_4_4_REV); newGlobal(t, "GL_UNSIGNED_SHORT_4_4_4_4_REV");
		pushInt(t, GL_UNSIGNED_SHORT_5_5_5_1); newGlobal(t, "GL_UNSIGNED_SHORT_5_5_5_1");
		pushInt(t, GL_UNSIGNED_SHORT_1_5_5_5_REV); newGlobal(t, "GL_UNSIGNED_SHORT_1_5_5_5_REV");
		pushInt(t, GL_UNSIGNED_INT_8_8_8_8); newGlobal(t, "GL_UNSIGNED_INT_8_8_8_8");
		pushInt(t, GL_UNSIGNED_INT_8_8_8_8_REV); newGlobal(t, "GL_UNSIGNED_INT_8_8_8_8_REV");
		pushInt(t, GL_UNSIGNED_INT_10_10_10_2); newGlobal(t, "GL_UNSIGNED_INT_10_10_10_2");
		pushInt(t, GL_UNSIGNED_INT_2_10_10_10_REV); newGlobal(t, "GL_UNSIGNED_INT_2_10_10_10_REV");
		pushInt(t, GL_LIGHT_MODEL_COLOR_CONTROL); newGlobal(t, "GL_LIGHT_MODEL_COLOR_CONTROL");
		pushInt(t, GL_SINGLE_COLOR); newGlobal(t, "GL_SINGLE_COLOR");
		pushInt(t, GL_SEPARATE_SPECULAR_COLOR); newGlobal(t, "GL_SEPARATE_SPECULAR_COLOR");
		pushInt(t, GL_TEXTURE_MIN_LOD); newGlobal(t, "GL_TEXTURE_MIN_LOD");
		pushInt(t, GL_TEXTURE_MAX_LOD); newGlobal(t, "GL_TEXTURE_MAX_LOD");
		pushInt(t, GL_TEXTURE_BASE_LEVEL); newGlobal(t, "GL_TEXTURE_BASE_LEVEL");
		pushInt(t, GL_TEXTURE_MAX_LEVEL); newGlobal(t, "GL_TEXTURE_MAX_LEVEL");
		pushInt(t, GL_SMOOTH_POINT_SIZE_RANGE); newGlobal(t, "GL_SMOOTH_POINT_SIZE_RANGE");
		pushInt(t, GL_SMOOTH_POINT_SIZE_GRANULARITY); newGlobal(t, "GL_SMOOTH_POINT_SIZE_GRANULARITY");
		pushInt(t, GL_SMOOTH_LINE_WIDTH_RANGE); newGlobal(t, "GL_SMOOTH_LINE_WIDTH_RANGE");
		pushInt(t, GL_SMOOTH_LINE_WIDTH_GRANULARITY); newGlobal(t, "GL_SMOOTH_LINE_WIDTH_GRANULARITY");
		pushInt(t, GL_ALIASED_POINT_SIZE_RANGE); newGlobal(t, "GL_ALIASED_POINT_SIZE_RANGE");
		pushInt(t, GL_ALIASED_LINE_WIDTH_RANGE); newGlobal(t, "GL_ALIASED_LINE_WIDTH_RANGE");
		pushInt(t, GL_PACK_SKIP_IMAGES); newGlobal(t, "GL_PACK_SKIP_IMAGES");
		pushInt(t, GL_PACK_IMAGE_HEIGHT); newGlobal(t, "GL_PACK_IMAGE_HEIGHT");
		pushInt(t, GL_UNPACK_SKIP_IMAGES); newGlobal(t, "GL_UNPACK_SKIP_IMAGES");
		pushInt(t, GL_UNPACK_IMAGE_HEIGHT); newGlobal(t, "GL_UNPACK_IMAGE_HEIGHT");
		pushInt(t, GL_TEXTURE_3D); newGlobal(t, "GL_TEXTURE_3D");
		pushInt(t, GL_PROXY_TEXTURE_3D); newGlobal(t, "GL_PROXY_TEXTURE_3D");
		pushInt(t, GL_TEXTURE_DEPTH); newGlobal(t, "GL_TEXTURE_DEPTH");
		pushInt(t, GL_TEXTURE_WRAP_R); newGlobal(t, "GL_TEXTURE_WRAP_R");
		pushInt(t, GL_MAX_3D_TEXTURE_SIZE); newGlobal(t, "GL_MAX_3D_TEXTURE_SIZE");
		pushInt(t, GL_TEXTURE_BINDING_3D); newGlobal(t, "GL_TEXTURE_BINDING_3D");
	}

	void loadGL13(CrocThread* t)
	{
		register(t, &wrapGL!(glActiveTexture), "glActiveTexture");
		register(t, &wrapGL!(glClientActiveTexture), "glClientActiveTexture");
		register(t, &wrapGL!(glMultiTexCoord1d), "glMultiTexCoord1d");
		register(t, &wrapGL!(glMultiTexCoord1dv), "glMultiTexCoord1dv");
		register(t, &wrapGL!(glMultiTexCoord1f), "glMultiTexCoord1f");
		register(t, &wrapGL!(glMultiTexCoord1fv), "glMultiTexCoord1fv");
		register(t, &wrapGL!(glMultiTexCoord1i), "glMultiTexCoord1i");
		register(t, &wrapGL!(glMultiTexCoord1iv), "glMultiTexCoord1iv");
		register(t, &wrapGL!(glMultiTexCoord1s), "glMultiTexCoord1s");
		register(t, &wrapGL!(glMultiTexCoord1sv), "glMultiTexCoord1sv");
		register(t, &wrapGL!(glMultiTexCoord2d), "glMultiTexCoord2d");
		register(t, &wrapGL!(glMultiTexCoord2dv), "glMultiTexCoord2dv");
		register(t, &wrapGL!(glMultiTexCoord2f), "glMultiTexCoord2f");
		register(t, &wrapGL!(glMultiTexCoord2fv), "glMultiTexCoord2fv");
		register(t, &wrapGL!(glMultiTexCoord2i), "glMultiTexCoord2i");
		register(t, &wrapGL!(glMultiTexCoord2iv), "glMultiTexCoord2iv");
		register(t, &wrapGL!(glMultiTexCoord2s), "glMultiTexCoord2s");
		register(t, &wrapGL!(glMultiTexCoord2sv), "glMultiTexCoord2sv");
		register(t, &wrapGL!(glMultiTexCoord3d), "glMultiTexCoord3d");
		register(t, &wrapGL!(glMultiTexCoord3dv), "glMultiTexCoord3dv");
		register(t, &wrapGL!(glMultiTexCoord3f), "glMultiTexCoord3f");
		register(t, &wrapGL!(glMultiTexCoord3fv), "glMultiTexCoord3fv");
		register(t, &wrapGL!(glMultiTexCoord3i), "glMultiTexCoord3i");
		register(t, &wrapGL!(glMultiTexCoord3iv), "glMultiTexCoord3iv");
		register(t, &wrapGL!(glMultiTexCoord3s), "glMultiTexCoord3s");
		register(t, &wrapGL!(glMultiTexCoord3sv), "glMultiTexCoord3sv");
		register(t, &wrapGL!(glMultiTexCoord4d), "glMultiTexCoord4d");
		register(t, &wrapGL!(glMultiTexCoord4dv), "glMultiTexCoord4dv");
		register(t, &wrapGL!(glMultiTexCoord4f), "glMultiTexCoord4f");
		register(t, &wrapGL!(glMultiTexCoord4fv), "glMultiTexCoord4fv");
		register(t, &wrapGL!(glMultiTexCoord4i), "glMultiTexCoord4i");
		register(t, &wrapGL!(glMultiTexCoord4iv), "glMultiTexCoord4iv");
		register(t, &wrapGL!(glMultiTexCoord4s), "glMultiTexCoord4s");
		register(t, &wrapGL!(glMultiTexCoord4sv), "glMultiTexCoord4sv");
		register(t, &wrapGL!(glLoadTransposeMatrixd), "glLoadTransposeMatrixd");
		register(t, &wrapGL!(glLoadTransposeMatrixf), "glLoadTransposeMatrixf");
		register(t, &wrapGL!(glMultTransposeMatrixd), "glMultTransposeMatrixd");
		register(t, &wrapGL!(glMultTransposeMatrixf), "glMultTransposeMatrixf");
		register(t, &wrapGL!(glSampleCoverage), "glSampleCoverage");
		register(t, &wrapGL!(glCompressedTexImage1D), "glCompressedTexImage1D");
		register(t, &wrapGL!(glCompressedTexImage2D), "glCompressedTexImage2D");
		register(t, &wrapGL!(glCompressedTexImage3D), "glCompressedTexImage3D");
		register(t, &wrapGL!(glCompressedTexSubImage1D), "glCompressedTexSubImage1D");
		register(t, &wrapGL!(glCompressedTexSubImage2D), "glCompressedTexSubImage2D");
		register(t, &wrapGL!(glCompressedTexSubImage3D), "glCompressedTexSubImage3D");
		register(t, &wrapGL!(glGetCompressedTexImage), "glGetCompressedTexImage");

		pushInt(t, GL_TEXTURE0); newGlobal(t, "GL_TEXTURE0");
		pushInt(t, GL_TEXTURE1); newGlobal(t, "GL_TEXTURE1");
		pushInt(t, GL_TEXTURE2); newGlobal(t, "GL_TEXTURE2");
		pushInt(t, GL_TEXTURE3); newGlobal(t, "GL_TEXTURE3");
		pushInt(t, GL_TEXTURE4); newGlobal(t, "GL_TEXTURE4");
		pushInt(t, GL_TEXTURE5); newGlobal(t, "GL_TEXTURE5");
		pushInt(t, GL_TEXTURE6); newGlobal(t, "GL_TEXTURE6");
		pushInt(t, GL_TEXTURE7); newGlobal(t, "GL_TEXTURE7");
		pushInt(t, GL_TEXTURE8); newGlobal(t, "GL_TEXTURE8");
		pushInt(t, GL_TEXTURE9); newGlobal(t, "GL_TEXTURE9");
		pushInt(t, GL_TEXTURE10); newGlobal(t, "GL_TEXTURE10");
		pushInt(t, GL_TEXTURE11); newGlobal(t, "GL_TEXTURE11");
		pushInt(t, GL_TEXTURE12); newGlobal(t, "GL_TEXTURE12");
		pushInt(t, GL_TEXTURE13); newGlobal(t, "GL_TEXTURE13");
		pushInt(t, GL_TEXTURE14); newGlobal(t, "GL_TEXTURE14");
		pushInt(t, GL_TEXTURE15); newGlobal(t, "GL_TEXTURE15");
		pushInt(t, GL_TEXTURE16); newGlobal(t, "GL_TEXTURE16");
		pushInt(t, GL_TEXTURE17); newGlobal(t, "GL_TEXTURE17");
		pushInt(t, GL_TEXTURE18); newGlobal(t, "GL_TEXTURE18");
		pushInt(t, GL_TEXTURE19); newGlobal(t, "GL_TEXTURE19");
		pushInt(t, GL_TEXTURE20); newGlobal(t, "GL_TEXTURE20");
		pushInt(t, GL_TEXTURE21); newGlobal(t, "GL_TEXTURE21");
		pushInt(t, GL_TEXTURE22); newGlobal(t, "GL_TEXTURE22");
		pushInt(t, GL_TEXTURE23); newGlobal(t, "GL_TEXTURE23");
		pushInt(t, GL_TEXTURE24); newGlobal(t, "GL_TEXTURE24");
		pushInt(t, GL_TEXTURE25); newGlobal(t, "GL_TEXTURE25");
		pushInt(t, GL_TEXTURE26); newGlobal(t, "GL_TEXTURE26");
		pushInt(t, GL_TEXTURE27); newGlobal(t, "GL_TEXTURE27");
		pushInt(t, GL_TEXTURE28); newGlobal(t, "GL_TEXTURE28");
		pushInt(t, GL_TEXTURE29); newGlobal(t, "GL_TEXTURE29");
		pushInt(t, GL_TEXTURE30); newGlobal(t, "GL_TEXTURE30");
		pushInt(t, GL_TEXTURE31); newGlobal(t, "GL_TEXTURE31");
		pushInt(t, GL_ACTIVE_TEXTURE); newGlobal(t, "GL_ACTIVE_TEXTURE");
		pushInt(t, GL_CLIENT_ACTIVE_TEXTURE); newGlobal(t, "GL_CLIENT_ACTIVE_TEXTURE");
		pushInt(t, GL_MAX_TEXTURE_UNITS); newGlobal(t, "GL_MAX_TEXTURE_UNITS");
		pushInt(t, GL_NORMAL_MAP); newGlobal(t, "GL_NORMAL_MAP");
		pushInt(t, GL_REFLECTION_MAP); newGlobal(t, "GL_REFLECTION_MAP");
		pushInt(t, GL_TEXTURE_CUBE_MAP); newGlobal(t, "GL_TEXTURE_CUBE_MAP");
		pushInt(t, GL_TEXTURE_BINDING_CUBE_MAP); newGlobal(t, "GL_TEXTURE_BINDING_CUBE_MAP");
		pushInt(t, GL_TEXTURE_CUBE_MAP_POSITIVE_X); newGlobal(t, "GL_TEXTURE_CUBE_MAP_POSITIVE_X");
		pushInt(t, GL_TEXTURE_CUBE_MAP_NEGATIVE_X); newGlobal(t, "GL_TEXTURE_CUBE_MAP_NEGATIVE_X");
		pushInt(t, GL_TEXTURE_CUBE_MAP_POSITIVE_Y); newGlobal(t, "GL_TEXTURE_CUBE_MAP_POSITIVE_Y");
		pushInt(t, GL_TEXTURE_CUBE_MAP_NEGATIVE_Y); newGlobal(t, "GL_TEXTURE_CUBE_MAP_NEGATIVE_Y");
		pushInt(t, GL_TEXTURE_CUBE_MAP_POSITIVE_Z); newGlobal(t, "GL_TEXTURE_CUBE_MAP_POSITIVE_Z");
		pushInt(t, GL_TEXTURE_CUBE_MAP_NEGATIVE_Z); newGlobal(t, "GL_TEXTURE_CUBE_MAP_NEGATIVE_Z");
		pushInt(t, GL_PROXY_TEXTURE_CUBE_MAP); newGlobal(t, "GL_PROXY_TEXTURE_CUBE_MAP");
		pushInt(t, GL_MAX_CUBE_MAP_TEXTURE_SIZE); newGlobal(t, "GL_MAX_CUBE_MAP_TEXTURE_SIZE");
		pushInt(t, GL_COMPRESSED_ALPHA); newGlobal(t, "GL_COMPRESSED_ALPHA");
		pushInt(t, GL_COMPRESSED_LUMINANCE); newGlobal(t, "GL_COMPRESSED_LUMINANCE");
		pushInt(t, GL_COMPRESSED_LUMINANCE_ALPHA); newGlobal(t, "GL_COMPRESSED_LUMINANCE_ALPHA");
		pushInt(t, GL_COMPRESSED_INTENSITY); newGlobal(t, "GL_COMPRESSED_INTENSITY");
		pushInt(t, GL_COMPRESSED_RGB); newGlobal(t, "GL_COMPRESSED_RGB");
		pushInt(t, GL_COMPRESSED_RGBA); newGlobal(t, "GL_COMPRESSED_RGBA");
		pushInt(t, GL_TEXTURE_COMPRESSION_HINT); newGlobal(t, "GL_TEXTURE_COMPRESSION_HINT");
		pushInt(t, GL_TEXTURE_COMPRESSED_IMAGE_SIZE); newGlobal(t, "GL_TEXTURE_COMPRESSED_IMAGE_SIZE");
		pushInt(t, GL_TEXTURE_COMPRESSED); newGlobal(t, "GL_TEXTURE_COMPRESSED");
		pushInt(t, GL_NUM_COMPRESSED_TEXTURE_FORMATS); newGlobal(t, "GL_NUM_COMPRESSED_TEXTURE_FORMATS");
		pushInt(t, GL_COMPRESSED_TEXTURE_FORMATS); newGlobal(t, "GL_COMPRESSED_TEXTURE_FORMATS");
		pushInt(t, GL_MULTISAMPLE); newGlobal(t, "GL_MULTISAMPLE");
		pushInt(t, GL_SAMPLE_ALPHA_TO_COVERAGE); newGlobal(t, "GL_SAMPLE_ALPHA_TO_COVERAGE");
		pushInt(t, GL_SAMPLE_ALPHA_TO_ONE); newGlobal(t, "GL_SAMPLE_ALPHA_TO_ONE");
		pushInt(t, GL_SAMPLE_COVERAGE); newGlobal(t, "GL_SAMPLE_COVERAGE");
		pushInt(t, GL_SAMPLE_BUFFERS); newGlobal(t, "GL_SAMPLE_BUFFERS");
		pushInt(t, GL_SAMPLES); newGlobal(t, "GL_SAMPLES");
		pushInt(t, GL_SAMPLE_COVERAGE_VALUE); newGlobal(t, "GL_SAMPLE_COVERAGE_VALUE");
		pushInt(t, GL_SAMPLE_COVERAGE_INVERT); newGlobal(t, "GL_SAMPLE_COVERAGE_INVERT");
		pushInt(t, GL_MULTISAMPLE_BIT); newGlobal(t, "GL_MULTISAMPLE_BIT");
		pushInt(t, GL_TRANSPOSE_MODELVIEW_MATRIX); newGlobal(t, "GL_TRANSPOSE_MODELVIEW_MATRIX");
		pushInt(t, GL_TRANSPOSE_PROJECTION_MATRIX); newGlobal(t, "GL_TRANSPOSE_PROJECTION_MATRIX");
		pushInt(t, GL_TRANSPOSE_TEXTURE_MATRIX); newGlobal(t, "GL_TRANSPOSE_TEXTURE_MATRIX");
		pushInt(t, GL_TRANSPOSE_COLOR_MATRIX); newGlobal(t, "GL_TRANSPOSE_COLOR_MATRIX");
		pushInt(t, GL_COMBINE); newGlobal(t, "GL_COMBINE");
		pushInt(t, GL_COMBINE_RGB); newGlobal(t, "GL_COMBINE_RGB");
		pushInt(t, GL_COMBINE_ALPHA); newGlobal(t, "GL_COMBINE_ALPHA");
		pushInt(t, GL_SOURCE0_RGB); newGlobal(t, "GL_SOURCE0_RGB");
		pushInt(t, GL_SOURCE1_RGB); newGlobal(t, "GL_SOURCE1_RGB");
		pushInt(t, GL_SOURCE2_RGB); newGlobal(t, "GL_SOURCE2_RGB");
		pushInt(t, GL_SOURCE0_ALPHA); newGlobal(t, "GL_SOURCE0_ALPHA");
		pushInt(t, GL_SOURCE1_ALPHA); newGlobal(t, "GL_SOURCE1_ALPHA");
		pushInt(t, GL_SOURCE2_ALPHA); newGlobal(t, "GL_SOURCE2_ALPHA");
		pushInt(t, GL_OPERAND0_RGB); newGlobal(t, "GL_OPERAND0_RGB");
		pushInt(t, GL_OPERAND1_RGB); newGlobal(t, "GL_OPERAND1_RGB");
		pushInt(t, GL_OPERAND2_RGB); newGlobal(t, "GL_OPERAND2_RGB");
		pushInt(t, GL_OPERAND0_ALPHA); newGlobal(t, "GL_OPERAND0_ALPHA");
		pushInt(t, GL_OPERAND1_ALPHA); newGlobal(t, "GL_OPERAND1_ALPHA");
		pushInt(t, GL_OPERAND2_ALPHA); newGlobal(t, "GL_OPERAND2_ALPHA");
		pushInt(t, GL_RGB_SCALE); newGlobal(t, "GL_RGB_SCALE");
		pushInt(t, GL_ADD_SIGNED); newGlobal(t, "GL_ADD_SIGNED");
		pushInt(t, GL_INTERPOLATE); newGlobal(t, "GL_INTERPOLATE");
		pushInt(t, GL_SUBTRACT); newGlobal(t, "GL_SUBTRACT");
		pushInt(t, GL_CONSTANT); newGlobal(t, "GL_CONSTANT");
		pushInt(t, GL_PRIMARY_COLOR); newGlobal(t, "GL_PRIMARY_COLOR");
		pushInt(t, GL_PREVIOUS); newGlobal(t, "GL_PREVIOUS");
		pushInt(t, GL_DOT3_RGB); newGlobal(t, "GL_DOT3_RGB");
		pushInt(t, GL_DOT3_RGBA); newGlobal(t, "GL_DOT3_RGBA");
		pushInt(t, GL_CLAMP_TO_BORDER); newGlobal(t, "GL_CLAMP_TO_BORDER");
	}

	void loadGL14(CrocThread* t)
	{
		register(t, &wrapGL!(glBlendFuncSeparate), "glBlendFuncSeparate");
		register(t, &wrapGL!(glFogCoordf), "glFogCoordf");
		register(t, &wrapGL!(glFogCoordfv), "glFogCoordfv");
		register(t, &wrapGL!(glFogCoordd), "glFogCoordd");
		register(t, &wrapGL!(glFogCoorddv), "glFogCoorddv");
		register(t, &wrapGL!(glFogCoordPointer), "glFogCoordPointer");
		register(t, &wrapGL!(glMultiDrawArrays), "glMultiDrawArrays");
// 		register(t, &wrapGL!(glMultiDrawElements), "glMultiDrawElements");
		register(t, &wrapGL!(glPointParameterf), "glPointParameterf");
		register(t, &wrapGL!(glPointParameterfv), "glPointParameterfv");
		register(t, &wrapGL!(glPointParameteri), "glPointParameteri");
		register(t, &wrapGL!(glPointParameteriv), "glPointParameteriv");
		register(t, &wrapGL!(glSecondaryColor3b), "glSecondaryColor3b");
		register(t, &wrapGL!(glSecondaryColor3bv), "glSecondaryColor3bv");
		register(t, &wrapGL!(glSecondaryColor3d), "glSecondaryColor3d");
		register(t, &wrapGL!(glSecondaryColor3dv), "glSecondaryColor3dv");
		register(t, &wrapGL!(glSecondaryColor3f), "glSecondaryColor3f");
		register(t, &wrapGL!(glSecondaryColor3fv), "glSecondaryColor3fv");
		register(t, &wrapGL!(glSecondaryColor3i), "glSecondaryColor3i");
		register(t, &wrapGL!(glSecondaryColor3iv), "glSecondaryColor3iv");
		register(t, &wrapGL!(glSecondaryColor3s), "glSecondaryColor3s");
		register(t, &wrapGL!(glSecondaryColor3sv), "glSecondaryColor3sv");
		register(t, &wrapGL!(glSecondaryColor3ub), "glSecondaryColor3ub");
		register(t, &wrapGL!(glSecondaryColor3ubv), "glSecondaryColor3ubv");
		register(t, &wrapGL!(glSecondaryColor3ui), "glSecondaryColor3ui");
		register(t, &wrapGL!(glSecondaryColor3uiv), "glSecondaryColor3uiv");
		register(t, &wrapGL!(glSecondaryColor3us), "glSecondaryColor3us");
		register(t, &wrapGL!(glSecondaryColor3usv), "glSecondaryColor3usv");
		register(t, &wrapGL!(glSecondaryColorPointer), "glSecondaryColorPointer");
		register(t, &wrapGL!(glWindowPos2d), "glWindowPos2d");
		register(t, &wrapGL!(glWindowPos2dv), "glWindowPos2dv");
		register(t, &wrapGL!(glWindowPos2f), "glWindowPos2f");
		register(t, &wrapGL!(glWindowPos2fv), "glWindowPos2fv");
		register(t, &wrapGL!(glWindowPos2i), "glWindowPos2i");
		register(t, &wrapGL!(glWindowPos2iv), "glWindowPos2iv");
		register(t, &wrapGL!(glWindowPos2s), "glWindowPos2s");
		register(t, &wrapGL!(glWindowPos2sv), "glWindowPos2sv");
		register(t, &wrapGL!(glWindowPos3d), "glWindowPos3d");
		register(t, &wrapGL!(glWindowPos3dv), "glWindowPos3dv");
		register(t, &wrapGL!(glWindowPos3f), "glWindowPos3f");
		register(t, &wrapGL!(glWindowPos3fv), "glWindowPos3fv");
		register(t, &wrapGL!(glWindowPos3i), "glWindowPos3i");
		register(t, &wrapGL!(glWindowPos3iv), "glWindowPos3iv");
		register(t, &wrapGL!(glWindowPos3s), "glWindowPos3s");
		register(t, &wrapGL!(glWindowPos3sv), "glWindowPos3sv");
		register(t, &wrapGL!(glBlendEquation), "glBlendEquation");
		register(t, &wrapGL!(glBlendColor), "glBlendColor");

		pushInt(t, GL_BLEND_DST_RGB); newGlobal(t, "GL_BLEND_DST_RGB");
		pushInt(t, GL_BLEND_SRC_RGB); newGlobal(t, "GL_BLEND_SRC_RGB");
		pushInt(t, GL_BLEND_DST_ALPHA); newGlobal(t, "GL_BLEND_DST_ALPHA");
		pushInt(t, GL_BLEND_SRC_ALPHA); newGlobal(t, "GL_BLEND_SRC_ALPHA");
		pushInt(t, GL_POINT_SIZE_MIN); newGlobal(t, "GL_POINT_SIZE_MIN");
		pushInt(t, GL_POINT_SIZE_MAX); newGlobal(t, "GL_POINT_SIZE_MAX");
		pushInt(t, GL_POINT_FADE_THRESHOLD_SIZE); newGlobal(t, "GL_POINT_FADE_THRESHOLD_SIZE");
		pushInt(t, GL_POINT_DISTANCE_ATTENUATION); newGlobal(t, "GL_POINT_DISTANCE_ATTENUATION");
		pushInt(t, GL_GENERATE_MIPMAP); newGlobal(t, "GL_GENERATE_MIPMAP");
		pushInt(t, GL_GENERATE_MIPMAP_HINT); newGlobal(t, "GL_GENERATE_MIPMAP_HINT");
		pushInt(t, GL_DEPTH_COMPONENT16); newGlobal(t, "GL_DEPTH_COMPONENT16");
		pushInt(t, GL_DEPTH_COMPONENT24); newGlobal(t, "GL_DEPTH_COMPONENT24");
		pushInt(t, GL_DEPTH_COMPONENT32); newGlobal(t, "GL_DEPTH_COMPONENT32");
		pushInt(t, GL_MIRRORED_REPEAT); newGlobal(t, "GL_MIRRORED_REPEAT");
		pushInt(t, GL_FOG_COORDINATE_SOURCE); newGlobal(t, "GL_FOG_COORDINATE_SOURCE");
		pushInt(t, GL_FOG_COORDINATE); newGlobal(t, "GL_FOG_COORDINATE");
		pushInt(t, GL_FRAGMENT_DEPTH); newGlobal(t, "GL_FRAGMENT_DEPTH");
		pushInt(t, GL_CURRENT_FOG_COORDINATE); newGlobal(t, "GL_CURRENT_FOG_COORDINATE");
		pushInt(t, GL_FOG_COORDINATE_ARRAY_TYPE); newGlobal(t, "GL_FOG_COORDINATE_ARRAY_TYPE");
		pushInt(t, GL_FOG_COORDINATE_ARRAY_STRIDE); newGlobal(t, "GL_FOG_COORDINATE_ARRAY_STRIDE");
		pushInt(t, GL_FOG_COORDINATE_ARRAY_POINTER); newGlobal(t, "GL_FOG_COORDINATE_ARRAY_POINTER");
		pushInt(t, GL_FOG_COORDINATE_ARRAY); newGlobal(t, "GL_FOG_COORDINATE_ARRAY");
		pushInt(t, GL_COLOR_SUM); newGlobal(t, "GL_COLOR_SUM");
		pushInt(t, GL_CURRENT_SECONDARY_COLOR); newGlobal(t, "GL_CURRENT_SECONDARY_COLOR");
		pushInt(t, GL_SECONDARY_COLOR_ARRAY_SIZE); newGlobal(t, "GL_SECONDARY_COLOR_ARRAY_SIZE");
		pushInt(t, GL_SECONDARY_COLOR_ARRAY_TYPE); newGlobal(t, "GL_SECONDARY_COLOR_ARRAY_TYPE");
		pushInt(t, GL_SECONDARY_COLOR_ARRAY_STRIDE); newGlobal(t, "GL_SECONDARY_COLOR_ARRAY_STRIDE");
		pushInt(t, GL_SECONDARY_COLOR_ARRAY_POINTER); newGlobal(t, "GL_SECONDARY_COLOR_ARRAY_POINTER");
		pushInt(t, GL_SECONDARY_COLOR_ARRAY); newGlobal(t, "GL_SECONDARY_COLOR_ARRAY");
		pushInt(t, GL_MAX_TEXTURE_LOD_BIAS); newGlobal(t, "GL_MAX_TEXTURE_LOD_BIAS");
		pushInt(t, GL_TEXTURE_FILTER_CONTROL); newGlobal(t, "GL_TEXTURE_FILTER_CONTROL");
		pushInt(t, GL_TEXTURE_LOD_BIAS); newGlobal(t, "GL_TEXTURE_LOD_BIAS");
		pushInt(t, GL_INCR_WRAP); newGlobal(t, "GL_INCR_WRAP");
		pushInt(t, GL_DECR_WRAP); newGlobal(t, "GL_DECR_WRAP");
		pushInt(t, GL_TEXTURE_DEPTH_SIZE); newGlobal(t, "GL_TEXTURE_DEPTH_SIZE");
		pushInt(t, GL_DEPTH_TEXTURE_MODE); newGlobal(t, "GL_DEPTH_TEXTURE_MODE");
		pushInt(t, GL_TEXTURE_COMPARE_MODE); newGlobal(t, "GL_TEXTURE_COMPARE_MODE");
		pushInt(t, GL_TEXTURE_COMPARE_FUNC); newGlobal(t, "GL_TEXTURE_COMPARE_FUNC");
		pushInt(t, GL_COMPARE_R_TO_TEXTURE); newGlobal(t, "GL_COMPARE_R_TO_TEXTURE");
		pushInt(t, GL_CONSTANT_COLOR); newGlobal(t, "GL_CONSTANT_COLOR");
		pushInt(t, GL_ONE_MINUS_CONSTANT_COLOR); newGlobal(t, "GL_ONE_MINUS_CONSTANT_COLOR");
		pushInt(t, GL_CONSTANT_ALPHA); newGlobal(t, "GL_CONSTANT_ALPHA");
		pushInt(t, GL_ONE_MINUS_CONSTANT_ALPHA); newGlobal(t, "GL_ONE_MINUS_CONSTANT_ALPHA");
		pushInt(t, GL_BLEND_COLOR); newGlobal(t, "GL_BLEND_COLOR");
		pushInt(t, GL_FUNC_ADD); newGlobal(t, "GL_FUNC_ADD");
		pushInt(t, GL_MIN); newGlobal(t, "GL_MIN");
		pushInt(t, GL_MAX); newGlobal(t, "GL_MAX");
		pushInt(t, GL_BLEND_EQUATION); newGlobal(t, "GL_BLEND_EQUATION");
		pushInt(t, GL_FUNC_SUBTRACT); newGlobal(t, "GL_FUNC_SUBTRACT");
		pushInt(t, GL_FUNC_REVERSE_SUBTRACT); newGlobal(t, "GL_FUNC_REVERSE_SUBTRACT");
	}

	void loadGL15(CrocThread* t)
	{
		register(t, &wrapGL!(glGenQueries), "glGenQueries");
		register(t, &wrapGL!(glDeleteQueries), "glDeleteQueries");
		register(t, &wrapGL!(glIsQuery), "glIsQuery");
		register(t, &wrapGL!(glBeginQuery), "glBeginQuery");
		register(t, &wrapGL!(glEndQuery), "glEndQuery");
		register(t, &wrapGL!(glGetQueryiv), "glGetQueryiv");
		register(t, &wrapGL!(glGetQueryObjectiv), "glGetQueryObjectiv");
		register(t, &wrapGL!(glGetQueryObjectuiv), "glGetQueryObjectuiv");
		register(t, &wrapGL!(glBindBuffer), "glBindBuffer");
		register(t, &wrapGL!(glDeleteBuffers), "glDeleteBuffers");
		register(t, &wrapGL!(glGenBuffers), "glGenBuffers");
		register(t, &wrapGL!(glIsBuffer), "glIsBuffer");
		register(t, &wrapGL!(glBufferData), "glBufferData");
		register(t, &wrapGL!(glBufferSubData), "glBufferSubData");
		register(t, &wrapGL!(glGetBufferSubData), "glGetBufferSubData");
		register(t, &crocglMapBuffer, "glMapBuffer");
		register(t, &wrapGL!(glUnmapBuffer), "glUnmapBuffer");
		register(t, &wrapGL!(glGetBufferParameteriv), "glGetBufferParameteriv");
// 		register(t, &wrapGL!(glGetBufferPointerv), "glGetBufferPointerv");

		pushInt(t, GL_BUFFER_SIZE); newGlobal(t, "GL_BUFFER_SIZE");
		pushInt(t, GL_BUFFER_USAGE); newGlobal(t, "GL_BUFFER_USAGE");
		pushInt(t, GL_QUERY_COUNTER_BITS); newGlobal(t, "GL_QUERY_COUNTER_BITS");
		pushInt(t, GL_CURRENT_QUERY); newGlobal(t, "GL_CURRENT_QUERY");
		pushInt(t, GL_QUERY_RESULT); newGlobal(t, "GL_QUERY_RESULT");
		pushInt(t, GL_QUERY_RESULT_AVAILABLE); newGlobal(t, "GL_QUERY_RESULT_AVAILABLE");
		pushInt(t, GL_ARRAY_BUFFER); newGlobal(t, "GL_ARRAY_BUFFER");
		pushInt(t, GL_ELEMENT_ARRAY_BUFFER); newGlobal(t, "GL_ELEMENT_ARRAY_BUFFER");
		pushInt(t, GL_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_ELEMENT_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_ELEMENT_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_VERTEX_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_VERTEX_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_NORMAL_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_NORMAL_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_COLOR_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_COLOR_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_INDEX_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_INDEX_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_TEXTURE_COORD_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_TEXTURE_COORD_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_EDGE_FLAG_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_EDGE_FLAG_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_SECONDARY_COLOR_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_SECONDARY_COLOR_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_FOG_COORDINATE_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_FOG_COORDINATE_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_WEIGHT_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_WEIGHT_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_READ_ONLY); newGlobal(t, "GL_READ_ONLY");
		pushInt(t, GL_WRITE_ONLY); newGlobal(t, "GL_WRITE_ONLY");
		pushInt(t, GL_READ_WRITE); newGlobal(t, "GL_READ_WRITE");
		pushInt(t, GL_BUFFER_ACCESS); newGlobal(t, "GL_BUFFER_ACCESS");
		pushInt(t, GL_BUFFER_MAPPED); newGlobal(t, "GL_BUFFER_MAPPED");
		pushInt(t, GL_BUFFER_MAP_POINTER); newGlobal(t, "GL_BUFFER_MAP_POINTER");
		pushInt(t, GL_STREAM_DRAW); newGlobal(t, "GL_STREAM_DRAW");
		pushInt(t, GL_STREAM_READ); newGlobal(t, "GL_STREAM_READ");
		pushInt(t, GL_STREAM_COPY); newGlobal(t, "GL_STREAM_COPY");
		pushInt(t, GL_STATIC_DRAW); newGlobal(t, "GL_STATIC_DRAW");
		pushInt(t, GL_STATIC_READ); newGlobal(t, "GL_STATIC_READ");
		pushInt(t, GL_STATIC_COPY); newGlobal(t, "GL_STATIC_COPY");
		pushInt(t, GL_DYNAMIC_DRAW); newGlobal(t, "GL_DYNAMIC_DRAW");
		pushInt(t, GL_DYNAMIC_READ); newGlobal(t, "GL_DYNAMIC_READ");
		pushInt(t, GL_DYNAMIC_COPY); newGlobal(t, "GL_DYNAMIC_COPY");
		pushInt(t, GL_SAMPLES_PASSED); newGlobal(t, "GL_SAMPLES_PASSED");
		pushInt(t, GL_FOG_COORD_SRC); newGlobal(t, "GL_FOG_COORD_SRC");
		pushInt(t, GL_FOG_COORD); newGlobal(t, "GL_FOG_COORD");
		pushInt(t, GL_CURRENT_FOG_COORD); newGlobal(t, "GL_CURRENT_FOG_COORD");
		pushInt(t, GL_FOG_COORD_ARRAY_TYPE); newGlobal(t, "GL_FOG_COORD_ARRAY_TYPE");
		pushInt(t, GL_FOG_COORD_ARRAY_STRIDE); newGlobal(t, "GL_FOG_COORD_ARRAY_STRIDE");
		pushInt(t, GL_FOG_COORD_ARRAY_POINTER); newGlobal(t, "GL_FOG_COORD_ARRAY_POINTER");
		pushInt(t, GL_FOG_COORD_ARRAY); newGlobal(t, "GL_FOG_COORD_ARRAY");
		pushInt(t, GL_FOG_COORD_ARRAY_BUFFER_BINDING); newGlobal(t, "GL_FOG_COORD_ARRAY_BUFFER_BINDING");
		pushInt(t, GL_SRC0_RGB); newGlobal(t, "GL_SRC0_RGB");
		pushInt(t, GL_SRC1_RGB); newGlobal(t, "GL_SRC1_RGB");
		pushInt(t, GL_SRC2_RGB); newGlobal(t, "GL_SRC2_RGB");
		pushInt(t, GL_SRC0_ALPHA); newGlobal(t, "GL_SRC0_ALPHA");
		pushInt(t, GL_SRC1_ALPHA); newGlobal(t, "GL_SRC1_ALPHA");
		pushInt(t, GL_SRC2_ALPHA); newGlobal(t, "GL_SRC2_ALPHA");
	}

	void loadGL20(CrocThread* t)
	{
		register(t, &wrapGL!(glBlendEquationSeparate), "glBlendEquationSeparate");
		register(t, &wrapGL!(glDrawBuffers), "glDrawBuffers");
		register(t, &wrapGL!(glStencilOpSeparate), "glStencilOpSeparate");
		register(t, &wrapGL!(glStencilFuncSeparate), "glStencilFuncSeparate");
		register(t, &wrapGL!(glStencilMaskSeparate), "glStencilMaskSeparate");
		register(t, &wrapGL!(glAttachShader), "glAttachShader");
		register(t, &wrapGL!(glBindAttribLocation), "glBindAttribLocation");
		register(t, &wrapGL!(glCompileShader), "glCompileShader");
		register(t, &wrapGL!(glCreateProgram), "glCreateProgram");
		register(t, &wrapGL!(glCreateShader), "glCreateShader");
		register(t, &wrapGL!(glDeleteProgram), "glDeleteProgram");
		register(t, &wrapGL!(glDeleteShader), "glDeleteShader");
		register(t, &wrapGL!(glDetachShader), "glDetachShader");
		register(t, &wrapGL!(glDisableVertexAttribArray), "glDisableVertexAttribArray");
		register(t, &wrapGL!(glEnableVertexAttribArray), "glEnableVertexAttribArray");
		register(t, &wrapGL!(glGetActiveAttrib), "glGetActiveAttrib");
		register(t, &wrapGL!(glGetActiveUniform), "glGetActiveUniform");
		register(t, &wrapGL!(glGetAttachedShaders), "glGetAttachedShaders");
		register(t, &wrapGL!(glGetAttribLocation), "glGetAttribLocation");
		register(t, &wrapGL!(glGetProgramiv), "glGetProgramiv");
		register(t, &wrapGL!(glGetProgramInfoLog), "glGetProgramInfoLog");
		register(t, &wrapGL!(glGetShaderiv), "glGetShaderiv");
		register(t, &wrapGL!(glGetShaderInfoLog), "glGetShaderInfoLog");
		register(t, &wrapGL!(glGetShaderSource), "glGetShaderSource");
		register(t, &wrapGL!(glGetUniformLocation), "glGetUniformLocation");
		register(t, &wrapGL!(glGetUniformfv), "glGetUniformfv");
		register(t, &wrapGL!(glGetUniformiv), "glGetUniformiv");
		register(t, &wrapGL!(glGetVertexAttribdv), "glGetVertexAttribdv");
		register(t, &wrapGL!(glGetVertexAttribfv), "glGetVertexAttribfv");
		register(t, &wrapGL!(glGetVertexAttribiv), "glGetVertexAttribiv");
// 		register(t, &wrapGL!(glGetVertexAttribPointerv), "glGetVertexAttribPointerv");
		register(t, &wrapGL!(glIsProgram), "glIsProgram");
		register(t, &wrapGL!(glIsShader), "glIsShader");
		register(t, &wrapGL!(glLinkProgram), "glLinkProgram");
		register(t, &crocglShaderSource, "glShaderSource");
		register(t, &wrapGL!(glUseProgram), "glUseProgram");
		register(t, &wrapGL!(glUniform1f), "glUniform1f");
		register(t, &wrapGL!(glUniform2f), "glUniform2f");
		register(t, &wrapGL!(glUniform3f), "glUniform3f");
		register(t, &wrapGL!(glUniform4f), "glUniform4f");
		register(t, &wrapGL!(glUniform1i), "glUniform1i");
		register(t, &wrapGL!(glUniform2i), "glUniform2i");
		register(t, &wrapGL!(glUniform3i), "glUniform3i");
		register(t, &wrapGL!(glUniform4i), "glUniform4i");
		register(t, &wrapGL!(glUniform1fv), "glUniform1fv");
		register(t, &wrapGL!(glUniform2fv), "glUniform2fv");
		register(t, &wrapGL!(glUniform3fv), "glUniform3fv");
		register(t, &wrapGL!(glUniform4fv), "glUniform4fv");
		register(t, &wrapGL!(glUniform1iv), "glUniform1iv");
		register(t, &wrapGL!(glUniform2iv), "glUniform2iv");
		register(t, &wrapGL!(glUniform3iv), "glUniform3iv");
		register(t, &wrapGL!(glUniform4iv), "glUniform4iv");
		register(t, &wrapGL!(glUniformMatrix2fv), "glUniformMatrix2fv");
		register(t, &wrapGL!(glUniformMatrix3fv), "glUniformMatrix3fv");
		register(t, &wrapGL!(glUniformMatrix4fv), "glUniformMatrix4fv");
		register(t, &wrapGL!(glValidateProgram), "glValidateProgram");
		register(t, &wrapGL!(glVertexAttrib1d), "glVertexAttrib1d");
		register(t, &wrapGL!(glVertexAttrib1dv), "glVertexAttrib1dv");
		register(t, &wrapGL!(glVertexAttrib1f), "glVertexAttrib1f");
		register(t, &wrapGL!(glVertexAttrib1fv), "glVertexAttrib1fv");
		register(t, &wrapGL!(glVertexAttrib1s), "glVertexAttrib1s");
		register(t, &wrapGL!(glVertexAttrib1sv), "glVertexAttrib1sv");
		register(t, &wrapGL!(glVertexAttrib2d), "glVertexAttrib2d");
		register(t, &wrapGL!(glVertexAttrib2dv), "glVertexAttrib2dv");
		register(t, &wrapGL!(glVertexAttrib2f), "glVertexAttrib2f");
		register(t, &wrapGL!(glVertexAttrib2fv), "glVertexAttrib2fv");
		register(t, &wrapGL!(glVertexAttrib2s), "glVertexAttrib2s");
		register(t, &wrapGL!(glVertexAttrib2sv), "glVertexAttrib2sv");
		register(t, &wrapGL!(glVertexAttrib3d), "glVertexAttrib3d");
		register(t, &wrapGL!(glVertexAttrib3dv), "glVertexAttrib3dv");
		register(t, &wrapGL!(glVertexAttrib3f), "glVertexAttrib3f");
		register(t, &wrapGL!(glVertexAttrib3fv), "glVertexAttrib3fv");
		register(t, &wrapGL!(glVertexAttrib3s), "glVertexAttrib3s");
		register(t, &wrapGL!(glVertexAttrib3sv), "glVertexAttrib3sv");
		register(t, &wrapGL!(glVertexAttrib4Nbv), "glVertexAttrib4Nbv");
		register(t, &wrapGL!(glVertexAttrib4Niv), "glVertexAttrib4Niv");
		register(t, &wrapGL!(glVertexAttrib4Nsv), "glVertexAttrib4Nsv");
		register(t, &wrapGL!(glVertexAttrib4Nub), "glVertexAttrib4Nub");
		register(t, &wrapGL!(glVertexAttrib4Nubv), "glVertexAttrib4Nubv");
		register(t, &wrapGL!(glVertexAttrib4Nuiv), "glVertexAttrib4Nuiv");
		register(t, &wrapGL!(glVertexAttrib4Nusv), "glVertexAttrib4Nusv");
		register(t, &wrapGL!(glVertexAttrib4bv), "glVertexAttrib4bv");
		register(t, &wrapGL!(glVertexAttrib4d), "glVertexAttrib4d");
		register(t, &wrapGL!(glVertexAttrib4dv), "glVertexAttrib4dv");
		register(t, &wrapGL!(glVertexAttrib4f), "glVertexAttrib4f");
		register(t, &wrapGL!(glVertexAttrib4fv), "glVertexAttrib4fv");
		register(t, &wrapGL!(glVertexAttrib4iv), "glVertexAttrib4iv");
		register(t, &wrapGL!(glVertexAttrib4s), "glVertexAttrib4s");
		register(t, &wrapGL!(glVertexAttrib4sv), "glVertexAttrib4sv");
		register(t, &wrapGL!(glVertexAttrib4ubv), "glVertexAttrib4ubv");
		register(t, &wrapGL!(glVertexAttrib4uiv), "glVertexAttrib4uiv");
		register(t, &wrapGL!(glVertexAttrib4usv), "glVertexAttrib4usv");
		register(t, &wrapGL!(glVertexAttribPointer), "glVertexAttribPointer");

		pushInt(t, GL_BLEND_EQUATION_RGB); newGlobal(t, "GL_BLEND_EQUATION_RGB");
		pushInt(t, GL_VERTEX_ATTRIB_ARRAY_ENABLED); newGlobal(t, "GL_VERTEX_ATTRIB_ARRAY_ENABLED");
		pushInt(t, GL_VERTEX_ATTRIB_ARRAY_SIZE); newGlobal(t, "GL_VERTEX_ATTRIB_ARRAY_SIZE");
		pushInt(t, GL_VERTEX_ATTRIB_ARRAY_STRIDE); newGlobal(t, "GL_VERTEX_ATTRIB_ARRAY_STRIDE");
		pushInt(t, GL_VERTEX_ATTRIB_ARRAY_TYPE); newGlobal(t, "GL_VERTEX_ATTRIB_ARRAY_TYPE");
		pushInt(t, GL_CURRENT_VERTEX_ATTRIB); newGlobal(t, "GL_CURRENT_VERTEX_ATTRIB");
		pushInt(t, GL_VERTEX_PROGRAM_POINT_SIZE); newGlobal(t, "GL_VERTEX_PROGRAM_POINT_SIZE");
		pushInt(t, GL_VERTEX_PROGRAM_TWO_SIDE); newGlobal(t, "GL_VERTEX_PROGRAM_TWO_SIDE");
		pushInt(t, GL_VERTEX_ATTRIB_ARRAY_POINTER); newGlobal(t, "GL_VERTEX_ATTRIB_ARRAY_POINTER");
		pushInt(t, GL_STENCIL_BACK_FUNC); newGlobal(t, "GL_STENCIL_BACK_FUNC");
		pushInt(t, GL_STENCIL_BACK_FAIL); newGlobal(t, "GL_STENCIL_BACK_FAIL");
		pushInt(t, GL_STENCIL_BACK_PASS_DEPTH_FAIL); newGlobal(t, "GL_STENCIL_BACK_PASS_DEPTH_FAIL");
		pushInt(t, GL_STENCIL_BACK_PASS_DEPTH_PASS); newGlobal(t, "GL_STENCIL_BACK_PASS_DEPTH_PASS");
		pushInt(t, GL_MAX_DRAW_BUFFERS); newGlobal(t, "GL_MAX_DRAW_BUFFERS");
		pushInt(t, GL_DRAW_BUFFER0); newGlobal(t, "GL_DRAW_BUFFER0");
		pushInt(t, GL_DRAW_BUFFER1); newGlobal(t, "GL_DRAW_BUFFER1");
		pushInt(t, GL_DRAW_BUFFER2); newGlobal(t, "GL_DRAW_BUFFER2");
		pushInt(t, GL_DRAW_BUFFER3); newGlobal(t, "GL_DRAW_BUFFER3");
		pushInt(t, GL_DRAW_BUFFER4); newGlobal(t, "GL_DRAW_BUFFER4");
		pushInt(t, GL_DRAW_BUFFER5); newGlobal(t, "GL_DRAW_BUFFER5");
		pushInt(t, GL_DRAW_BUFFER6); newGlobal(t, "GL_DRAW_BUFFER6");
		pushInt(t, GL_DRAW_BUFFER7); newGlobal(t, "GL_DRAW_BUFFER7");
		pushInt(t, GL_DRAW_BUFFER8); newGlobal(t, "GL_DRAW_BUFFER8");
		pushInt(t, GL_DRAW_BUFFER9); newGlobal(t, "GL_DRAW_BUFFER9");
		pushInt(t, GL_DRAW_BUFFER10); newGlobal(t, "GL_DRAW_BUFFER10");
		pushInt(t, GL_DRAW_BUFFER11); newGlobal(t, "GL_DRAW_BUFFER11");
		pushInt(t, GL_DRAW_BUFFER12); newGlobal(t, "GL_DRAW_BUFFER12");
		pushInt(t, GL_DRAW_BUFFER13); newGlobal(t, "GL_DRAW_BUFFER13");
		pushInt(t, GL_DRAW_BUFFER14); newGlobal(t, "GL_DRAW_BUFFER14");
		pushInt(t, GL_DRAW_BUFFER15); newGlobal(t, "GL_DRAW_BUFFER15");
		pushInt(t, GL_BLEND_EQUATION_ALPHA); newGlobal(t, "GL_BLEND_EQUATION_ALPHA");
		pushInt(t, GL_POINT_SPRITE); newGlobal(t, "GL_POINT_SPRITE");
		pushInt(t, GL_COORD_REPLACE); newGlobal(t, "GL_COORD_REPLACE");
		pushInt(t, GL_MAX_VERTEX_ATTRIBS); newGlobal(t, "GL_MAX_VERTEX_ATTRIBS");
		pushInt(t, GL_VERTEX_ATTRIB_ARRAY_NORMALIZED); newGlobal(t, "GL_VERTEX_ATTRIB_ARRAY_NORMALIZED");
		pushInt(t, GL_MAX_TEXTURE_COORDS); newGlobal(t, "GL_MAX_TEXTURE_COORDS");
		pushInt(t, GL_MAX_TEXTURE_IMAGE_UNITS); newGlobal(t, "GL_MAX_TEXTURE_IMAGE_UNITS");
		pushInt(t, GL_FRAGMENT_SHADER); newGlobal(t, "GL_FRAGMENT_SHADER");
		pushInt(t, GL_VERTEX_SHADER); newGlobal(t, "GL_VERTEX_SHADER");
		pushInt(t, GL_MAX_FRAGMENT_UNIFORM_COMPONENTS); newGlobal(t, "GL_MAX_FRAGMENT_UNIFORM_COMPONENTS");
		pushInt(t, GL_MAX_VERTEX_UNIFORM_COMPONENTS); newGlobal(t, "GL_MAX_VERTEX_UNIFORM_COMPONENTS");
		pushInt(t, GL_MAX_VARYING_FLOATS); newGlobal(t, "GL_MAX_VARYING_FLOATS");
		pushInt(t, GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS); newGlobal(t, "GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS");
		pushInt(t, GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS); newGlobal(t, "GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS");
		pushInt(t, GL_SHADER_TYPE); newGlobal(t, "GL_SHADER_TYPE");
		pushInt(t, GL_FLOAT_VEC2); newGlobal(t, "GL_FLOAT_VEC2");
		pushInt(t, GL_FLOAT_VEC3); newGlobal(t, "GL_FLOAT_VEC3");
		pushInt(t, GL_FLOAT_VEC4); newGlobal(t, "GL_FLOAT_VEC4");
		pushInt(t, GL_INT_VEC2); newGlobal(t, "GL_INT_VEC2");
		pushInt(t, GL_INT_VEC3); newGlobal(t, "GL_INT_VEC3");
		pushInt(t, GL_INT_VEC4); newGlobal(t, "GL_INT_VEC4");
		pushInt(t, GL_BOOL); newGlobal(t, "GL_BOOL");
		pushInt(t, GL_BOOL_VEC2); newGlobal(t, "GL_BOOL_VEC2");
		pushInt(t, GL_BOOL_VEC3); newGlobal(t, "GL_BOOL_VEC3");
		pushInt(t, GL_BOOL_VEC4); newGlobal(t, "GL_BOOL_VEC4");
		pushInt(t, GL_FLOAT_MAT2); newGlobal(t, "GL_FLOAT_MAT2");
		pushInt(t, GL_FLOAT_MAT3); newGlobal(t, "GL_FLOAT_MAT3");
		pushInt(t, GL_FLOAT_MAT4); newGlobal(t, "GL_FLOAT_MAT4");
		pushInt(t, GL_SAMPLER_1D); newGlobal(t, "GL_SAMPLER_1D");
		pushInt(t, GL_SAMPLER_2D); newGlobal(t, "GL_SAMPLER_2D");
		pushInt(t, GL_SAMPLER_3D); newGlobal(t, "GL_SAMPLER_3D");
		pushInt(t, GL_SAMPLER_CUBE); newGlobal(t, "GL_SAMPLER_CUBE");
		pushInt(t, GL_SAMPLER_1D_SHADOW); newGlobal(t, "GL_SAMPLER_1D_SHADOW");
		pushInt(t, GL_SAMPLER_2D_SHADOW); newGlobal(t, "GL_SAMPLER_2D_SHADOW");
		pushInt(t, GL_DELETE_STATUS); newGlobal(t, "GL_DELETE_STATUS");
		pushInt(t, GL_COMPILE_STATUS); newGlobal(t, "GL_COMPILE_STATUS");
		pushInt(t, GL_LINK_STATUS); newGlobal(t, "GL_LINK_STATUS");
		pushInt(t, GL_VALIDATE_STATUS); newGlobal(t, "GL_VALIDATE_STATUS");
		pushInt(t, GL_INFO_LOG_LENGTH); newGlobal(t, "GL_INFO_LOG_LENGTH");
		pushInt(t, GL_ATTACHED_SHADERS); newGlobal(t, "GL_ATTACHED_SHADERS");
		pushInt(t, GL_ACTIVE_UNIFORMS); newGlobal(t, "GL_ACTIVE_UNIFORMS");
		pushInt(t, GL_ACTIVE_UNIFORM_MAX_LENGTH); newGlobal(t, "GL_ACTIVE_UNIFORM_MAX_LENGTH");
		pushInt(t, GL_SHADER_SOURCE_LENGTH); newGlobal(t, "GL_SHADER_SOURCE_LENGTH");
		pushInt(t, GL_ACTIVE_ATTRIBUTES); newGlobal(t, "GL_ACTIVE_ATTRIBUTES");
		pushInt(t, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH); newGlobal(t, "GL_ACTIVE_ATTRIBUTE_MAX_LENGTH");
		pushInt(t, GL_FRAGMENT_SHADER_DERIVATIVE_HINT); newGlobal(t, "GL_FRAGMENT_SHADER_DERIVATIVE_HINT");
		pushInt(t, GL_SHADING_LANGUAGE_VERSION); newGlobal(t, "GL_SHADING_LANGUAGE_VERSION");
		pushInt(t, GL_CURRENT_PROGRAM); newGlobal(t, "GL_CURRENT_PROGRAM");
		pushInt(t, GL_POINT_SPRITE_COORD_ORIGIN); newGlobal(t, "GL_POINT_SPRITE_COORD_ORIGIN");
		pushInt(t, GL_LOWER_LEFT); newGlobal(t, "GL_LOWER_LEFT");
		pushInt(t, GL_UPPER_LEFT); newGlobal(t, "GL_UPPER_LEFT");
		pushInt(t, GL_STENCIL_BACK_REF); newGlobal(t, "GL_STENCIL_BACK_REF");
		pushInt(t, GL_STENCIL_BACK_VALUE_MASK); newGlobal(t, "GL_STENCIL_BACK_VALUE_MASK");
		pushInt(t, GL_STENCIL_BACK_WRITEMASK); newGlobal(t, "GL_STENCIL_BACK_WRITEMASK");
	}

	void loadGL21(CrocThread* t)
	{
		register(t, &wrapGL!(glUniformMatrix2x3fv), "glUniformMatrix2x3fv");
		register(t, &wrapGL!(glUniformMatrix3x2fv), "glUniformMatrix3x2fv");
		register(t, &wrapGL!(glUniformMatrix2x4fv), "glUniformMatrix2x4fv");
		register(t, &wrapGL!(glUniformMatrix4x2fv), "glUniformMatrix4x2fv");
		register(t, &wrapGL!(glUniformMatrix3x4fv), "glUniformMatrix3x4fv");
		register(t, &wrapGL!(glUniformMatrix4x3fv), "glUniformMatrix4x3fv");

		pushInt(t, GL_CURRENT_RASTER_SECONDARY_COLOR); newGlobal(t, "GL_CURRENT_RASTER_SECONDARY_COLOR");
		pushInt(t, GL_PIXEL_PACK_BUFFER); newGlobal(t, "GL_PIXEL_PACK_BUFFER");
		pushInt(t, GL_PIXEL_UNPACK_BUFFER); newGlobal(t, "GL_PIXEL_UNPACK_BUFFER");
		pushInt(t, GL_PIXEL_PACK_BUFFER_BINDING); newGlobal(t, "GL_PIXEL_PACK_BUFFER_BINDING");
		pushInt(t, GL_PIXEL_UNPACK_BUFFER_BINDING); newGlobal(t, "GL_PIXEL_UNPACK_BUFFER_BINDING");
		pushInt(t, GL_FLOAT_MAT2x3); newGlobal(t, "GL_FLOAT_MAT2x3");
		pushInt(t, GL_FLOAT_MAT2x4); newGlobal(t, "GL_FLOAT_MAT2x4");
		pushInt(t, GL_FLOAT_MAT3x2); newGlobal(t, "GL_FLOAT_MAT3x2");
		pushInt(t, GL_FLOAT_MAT3x4); newGlobal(t, "GL_FLOAT_MAT3x4");
		pushInt(t, GL_FLOAT_MAT4x2); newGlobal(t, "GL_FLOAT_MAT4x2");
		pushInt(t, GL_FLOAT_MAT4x3); newGlobal(t, "GL_FLOAT_MAT4x3");
		pushInt(t, GL_SRGB); newGlobal(t, "GL_SRGB");
		pushInt(t, GL_SRGB8); newGlobal(t, "GL_SRGB8");
		pushInt(t, GL_SRGB_ALPHA); newGlobal(t, "GL_SRGB_ALPHA");
		pushInt(t, GL_SRGB8_ALPHA8); newGlobal(t, "GL_SRGB8_ALPHA8");
		pushInt(t, GL_SLUMINANCE_ALPHA); newGlobal(t, "GL_SLUMINANCE_ALPHA");
		pushInt(t, GL_SLUMINANCE8_ALPHA8); newGlobal(t, "GL_SLUMINANCE8_ALPHA8");
		pushInt(t, GL_SLUMINANCE); newGlobal(t, "GL_SLUMINANCE");
		pushInt(t, GL_SLUMINANCE8); newGlobal(t, "GL_SLUMINANCE8");
		pushInt(t, GL_COMPRESSED_SRGB); newGlobal(t, "GL_COMPRESSED_SRGB");
		pushInt(t, GL_COMPRESSED_SRGB_ALPHA); newGlobal(t, "GL_COMPRESSED_SRGB_ALPHA");
		pushInt(t, GL_COMPRESSED_SLUMINANCE); newGlobal(t, "GL_COMPRESSED_SLUMINANCE");
		pushInt(t, GL_COMPRESSED_SLUMINANCE_ALPHA); newGlobal(t, "GL_COMPRESSED_SLUMINANCE_ALPHA");
	}
}

}