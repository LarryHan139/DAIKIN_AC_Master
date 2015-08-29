function getIntProperty(strPropertyName)   
    return tonumber(tostring(Properties[strPropertyName]))
end

function getIntProperty2(strPropertyName)   
    return tonumber(string.gsub(tostring(Properties[strPropertyName]), "^%s*(.-)%s*$", "%1"))
end
function getStringProperty(strPropertyName)
    return string.gsub(tostring(Properties[strPropertyName]), "^%s*(.-)%s*$", "%1")
end