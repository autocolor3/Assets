local aes = loadstring(game:HttpGet("https://raw.githubusercontent.com/autocolor3/Assets/refs/heads/main/aes.lua"))()
local base64 = loadstring(game:HttpGet("https://raw.githubusercontent.com/autocolor3/Assets/refs/heads/main/base64.lua"))()
local hashlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/autocolor3/Assets/refs/heads/main/hashlib.lua"))()
local lz4 = loadstring(game:HttpGet("https://raw.githubusercontent.com/autocolor3/Assets/refs/heads/main/lz4.lua"))()

local crypt = {}

do
    local b64 = {
        encode = function(input)
            local Type = type(input)
            if Type ~= "string" and Type ~= "number" then
                return error("arg #1 must be type string or number", 2)
            end

            return if input == "" then input else buffer.tostring(base64.encode(buffer.fromstring(input)))
        end,
        decode = function(input)
            local Type = type(input)
            if Type ~= "string" and Type ~= "number" then
                return error("arg #1 must be type string or number", 2)
            end

            return if input == "" then input else buffer.tostring(base64.decode(buffer.fromstring(input)))
        end,
    }
    crypt.base64 = b64

    crypt.base64encode = b64.encode
    crypt.base64_encode = b64.encode

    crypt.base64decode = b64.decode
    crypt.base64_decode = b64.decode
end

do
    local modes = {}

    for _, ciphermode in { "ECB", "CBC", "PCBC", "CFB", "OFB", "CTR" } do -- Missing: GCM (important)
        local encrypt = aes["encrypt_" .. ciphermode]
        local decrypt = aes["decrypt_" .. ciphermode]

        modes[string.lower(ciphermode)] = { encrypt = encrypt, decrypt = decrypt or encrypt }
    end

    -- Function to add PKCS#7 padding to a string
    local function PKCS7_unpad(inputString)
        local blockSize = 16
        local length = (#inputString % blockSize)

        -- Only add padding if needed
        if 0 == length then
            return inputString
        end

        local paddingSize = blockSize - length

        local padding = string.rep(string.char(paddingSize), paddingSize)
        return inputString .. padding
    end

    -- Function to remove PKCS#7 padding from a padded string
    local function PKCS7_pad(paddedString)
        local lastByte = string.byte(paddedString, -1)

        -- Check if padding is present
        if lastByte <= 16 and 0 < lastByte then
            return string.sub(paddedString, 1, -lastByte - 1)
        else
            return paddedString
        end
    end

    local function table_type(t)
        local ct = 1
        for i in t do
            if i ~= ct then
                return "dictionary"
            end
            ct += 1
        end
        return "array"
    end

    local function bytes_to_char(t)
        return string.char(unpack(t))
    end

    local function crypt_generalized(action: string?)
        return function(data: string, key: string, iv: string?, mode: string?): (string, string)
            if mode and type(mode) == "string" then
                mode = string.lower(mode)
                mode = modes[mode]
            else
                mode = modes.cbc -- Default
            end

            if iv then
                iv = crypt.base64decode(iv)
                pcall(function()
                    iv = game:GetService("HttpService"):JSONDecode(iv)
                end)
                if 16 < #iv then
                    iv = string.sub(iv, 1, 16)
                elseif #iv < 16 then
                    iv = PKCS7_unpad(iv)
                end
            end

            pcall(function()
                key = crypt.base64decode(key)
            end)

            -- TODO This code below is even worse
            local crypt_f = mode[action]
            data, iv = crypt_f(key, if action == "encrypt" then PKCS7_unpad(data) else crypt.base64decode(data), iv)

            data = bytes_to_char(data)

            if action == "decrypt" then
                data = PKCS7_pad(data)
            else
                if table_type(iv) == "array" then
                    iv = bytes_to_char(iv)
                else
                    iv = game:GetService("HttpService"):JSONEncode(iv)
                end
                iv = crypt.base64encode(iv)
                data = crypt.base64encode(data)
            end

            return data, iv
        end
    end
    crypt.encrypt = crypt_generalized("encrypt")
    crypt.decrypt = crypt_generalized("decrypt")
end

function crypt.generatebytes(size: number): string
    local randomBytes = table.create(size)
    for i = 1, size do
        randomBytes[i] = string.char(math.random(0, 255))
    end

    return crypt.base64encode(table.concat(randomBytes))
end

function crypt.generatekey()
    return crypt.generatebytes(32)
end

function crypt.hash(data: string, algorithm: string): string
    return hashlib[string.gsub(algorithm, "-", "_")](data)
end

function crypt.hmac(data: string, key: string, asBinary: boolean): string
    return hashlib.hmac(hashlib.sha512_256, data, key, asBinary)
end

getgenv().encrypt = crypt_generalized("encrypt")
getgenv().decrypt = crypt_generalized("decrypt")
getgenv().encode = base64encode
getgenv().decode = base64decode
getgenv().lz4compress = lz4compress
getgenv().lz4decompress = lz4decompress  

getgenv().crypt = crypt
getgenv().base64 = b64
getgenv().crypt.encrypt = crypt_generalized("encrypt")
getgenv().crypt.decrypt = crypt_generalized("decrypt")
getgenv().base64.encode = base64encode
getgenv().base64.decode = base64decode
getgenv().crypt.lz4compress = lz4compress
getgenv().crypt.lz4decompress = lz4decompress  

getgenv().crypt.generatekey = crypt.generatekey
getgenv().generatekey = crypt.generatekey
getgenv().crypt.hash = crypt.hash
getgenv().hash = crypt.hash
getgenv().crypt.hmac = crypt.hmac
getgenv().hmac = crypt.hmac
getgenv().crypt.generatebytes = crypt.generatebytes
getgenv().generatebytes = crypt.generatebytes
