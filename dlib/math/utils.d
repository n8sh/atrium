/*
Copyright (c) 2011-2015 Timur Gafarov 

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dlib.math.utils;

private 
{
    import core.stdc.stdlib;
    import std.math;
}

public:

/*
 * Very small value
 */
enum EPSILON = 0.00000001;

/*
 * Axes of Cartesian space
 */
enum Axis
{
    x = 0, y = 1, z = 2
}

/*
 * Convert degrees to radians
 * and vice-versa
 */
T degtorad(T) (T angle) nothrow
{
    return (angle / 180.0) * PI;
}

T radtodeg(T) (T angle) nothrow
{
    return (angle / PI) * 180.0;
}

/*
 * Find maximum of three values
 */
T max3(T) (T x, T y, T z) nothrow
{
    T temp = (x > y)? x : y;
    return (temp > z) ? temp : z;
}

T min3(T) (T x, T y, T z) nothrow
{
    T temp = (x < y)? x : y;
    return (temp < z) ? temp : z;
}

/*
 * Limit to given range
 */
static if (__traits(compiles, (){import std.algorithm: clamp;}))
{
    public import std.algorithm: clamp;
}
else
{
    T clamp(T) (T v, T minimal, T maximal) nothrow
    {
        if (v > minimal)
        {
            if (v < maximal) return v;
                else return maximal;
        }
        else return minimal;
    }
}

/*
 * Almost zero
 */
bool isConsiderZero(T) (T f) nothrow
{
    //enum ZERO = 1.0e-6;
    return (abs(f) < EPSILON);
}

/*
 * Powers
 */
bool isPowerOfTwo(T)(T x) nothrow
{
    return (x != 0) && ((x & (x - 1)) == 0);
} 

T nextPowerOfTwo(T) (T k) nothrow
{
    if (k == 0) 
        return 1;
    k--;
    for (T i = 1; i < T.sizeof * 8; i <<= 1)
        k = k | k >> i;
    return k + 1;
}

T nextPowerOfTen(T) (T k) nothrow
{
    return pow(10, cast(int)ceil(log10(k)));
}

/*
 * Array operations
 */
T sum(T) (T[] array...) nothrow
{
    T result = 0;
    foreach(v; array) 
        result += v;
    return result;
}

T[] invertArray(T) (T[] array...) nothrow
{
    auto result = new T[array.length];
    foreach(i, v; array) 
        result[i] = -v;
    return result;
}

bool allIsZero(T) (T[] array...) nothrow
{
    foreach(i, v; array) 
        if (v != 0) return false;
    return true;
}

bool oneOfIsZero(T) (T[] array...) nothrow
{
    foreach(i, v; array) 
        if (v == 0) return true;
    return false;
}

/*
 * Byte operations
 */
version (BigEndian)
{
    uint bigEndian(uint value) nothrow
    {
        return value;
    }

    uint networkByteOrder(uint value) nothrow
    {
        return value;
    }
}

version (LittleEndian) 
{
    uint bigEndian(uint value) nothrow
    {
        return value << 24
            | (value & 0x0000FF00) << 8
            | (value & 0x00FF0000) >> 8
            |  value >> 24;
    }

    uint networkByteOrder(uint value) nothrow
    {
        return bigEndian(value);
    }
}

uint bytesToUint(ubyte[4] src) nothrow
{
    return (src[0] << 24 | src[1] << 16 | src[2] << 8 | src[3]); 
}

/*
 * Field of view (FOV)
 */
T fovYfromX(T) (T xfov, T aspectRatio) nothrow
{
    xfov = degtorad(xfov);
    T yfov = 2.0 * atan(tan(xfov * 0.5)/aspectRatio);
    return radtodeg(yfov);
}

T fovXfromY(T) (T yfov, T aspectRatio) nothrow
{
    yfov = degtorad(yfov);
    T xfov = 2.0 * atan(tan(yfov * 0.5) * aspectRatio);
    return radtodeg(xfov);
}

/*
 * Misc functions
 */
 
int sign(T)(T x) nothrow
{
    return (x > 0) - (x < 0);
}

void swap(T)(T* a, T* b)
{
    T c = *a;
    *a = *b;
    *b = c;
}

bool isPerfectSquare(float n) nothrow
{
    float r = sqrt(n);
    return(r * r == n);
}
