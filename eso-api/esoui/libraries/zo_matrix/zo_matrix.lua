
---
--@type Matrix33

---
--@field [parent=#Matrix33] #number _11

---
--@field [parent=#Matrix33] #number _12

---
--@field [parent=#Matrix33] #number _13

---
--@field [parent=#Matrix33] #number _21

---
--@field [parent=#Matrix33] #number _22

---
--@field [parent=#Matrix33] #number _23

---
--@field [parent=#Matrix33] #number _31

---
--@field [parent=#Matrix33] #number _32

---
--@field [parent=#Matrix33] #number _33

---
-- @param #Matrix33 m
function zo_setToIdentityMatrix33(m)
    m._11 = 1
    m._12 = 0
    m._13 = 0
    m._21 = 0
    m._22 = 1
    m._23 = 0
    m._31 = 0
    m._32 = 0
    m._33 = 1
end

---
-- @param #Matrix33 m
function zo_setToRotationMatrix2D(m, radians)
    local cosResult = math.cos(radians)
    local sinResult = math.sin(radians)

    m._11 = cosResult
    m._12 = sinResult
    m._13 = 0
    m._21 = -sinResult
    m._22 = cosResult
    m._23 = 0
    m._31 = 0
    m._32 = 0
    m._33 = 1
end

---
-- @param #Matrix33 m
function zo_setToTranslationMatrix2D(m, x, y)
    m._11 = 1
    m._12 = 0
    m._13 = x
    m._21 = 0
    m._22 = 1
    m._23 = -y
    m._31 = 0
    m._32 = 0
    m._33 = 1
end

---
-- @param #Matrix33 m
function zo_setToScaleMatrix2D(m, scale)
    m._11 = scale
    m._12 = 0
    m._13 = 0
    m._21 = 0
    m._22 = scale
    m._23 = 0
    m._31 = 0
    m._32 = 0
    m._33 = 1
end

---
-- @param #Matrix33 a
-- @param #Matrix33 b
-- @param #Matrix33 result
function zo_matrixMultiply33x33(a , b , result )
    local _11 = a._11 * b._11 + a._12 * b._21 + a._13 * b._31
    local _12 = a._11 * b._12 + a._12 * b._22 + a._13 * b._32
    local _13 = a._11 * b._13 + a._12 * b._23 + a._13 * b._33
    local _21 = a._21 * b._11 + a._22 * b._21 + a._23 * b._31
    local _22 = a._21 * b._12 + a._22 * b._22 + a._23 * b._32
    local _23 = a._21 * b._13 + a._22 * b._23 + a._23 * b._33
    local _31 = a._31 * b._11 + a._32 * b._21 + a._33 * b._31
    local _32 = a._31 * b._12 + a._32 * b._22 + a._33 * b._32
    local _33 = a._31 * b._13 + a._32 * b._23 + a._33 * b._33

    result._11 = _11
    result._12 = _12
    result._13 = _13
    result._21 = _21
    result._22 = _22
    result._23 = _23
    result._31 = _31
    result._32 = _32
    result._33 = _33
end