require "mybit"
require "commonUtil"

MAP_RC_Binding={
    [1]=0,
    [2]=0,
    [3]=0,
    [4]=0,
    [5]=0,
    [6]=0,
    [7]=0,
    [8]=0,
    [9]=0,
    [10]=0,
    [11]=0,
    [12]=0,
    [13]=0,
    [14]=0,
    [15]=0,
    [16]=0
    } --保存 RCID和BindingID的对应关系

ARR_BUFFER_GET={}

ARR_BUFFER_CRC={}

--[[=================================================================================================]]--

function OnDriverInit()
    SetGlobals()
end

function OnDriverUpdate()
    SetGlobals()
end

function OnDriverLateInit()
    SetGlobals()
    checkAuthorization()
    --===========================
    MAP_RC_Binding[1]=0
    MAP_RC_Binding[2]=0
    MAP_RC_Binding[3]=0
    MAP_RC_Binding[4]=0
    MAP_RC_Binding[5]=0
    MAP_RC_Binding[6]=0
    MAP_RC_Binding[7]=0
    MAP_RC_Binding[8]=0
    MAP_RC_Binding[9]=0
    MAP_RC_Binding[10]=0
    MAP_RC_Binding[11]=0
    MAP_RC_Binding[12]=0
    MAP_RC_Binding[13]=0
    MAP_RC_Binding[14]=0
    MAP_RC_Binding[15]=0
    MAP_RC_Binding[16]=0
end

function SetGlobals()
    gSerialId=101
    gBoxAddress=getIntProperty('Box Address')
    gPreRC_GET=0 --保存Box中执行查询命令的RC的编号（因返回时，不带RC编号）
    gPreRC_SET=0
    --gPreCMD --保存前一条设置命令
    gDataCount=0
    gIsWaiting=false
    gAuthCode=string.upper(getStringProperty('Auth Code'))
    gAuthed=false
end

--[[
    发送至Proxy
]]
function SendToProxy(idBinding, strCommand, tParams)
    if(gAuthed~=true) then
	   print("权限验证失败")
	   return
    end
    
    print("【Master】SendToProxy[" .. idBinding.. "]["..strCommand.."]")
    C4:SendToProxy(idBinding, strCommand.."abc", strParam)
end

--[[
    由Proxy接收
]]
function ReceivedFromProxy(idBinding, strCommand, tParams)
    if(gAuthed~=true) then
	   print("权限验证失败")
	   return
    end
    
    print("【Master】ReceivedFromProxy[" .. idBinding.. "]["..strCommand.."]")

    if(string.find(strCommand, "Slave")~=nil) then
	   local rcID=tonumber(tParams["RCID"])
	   print("tParams['RCID']:"..tParams["RCID"]..";idBinding:"..idBinding)
	   MAP_RC_Binding[rcID]=idBinding
	   local cmd=generateSerialCommand(rcID,strCommand,tParams)

    end
end


--[[
    根据条件生成485串口命令
]]
function generateSerialCommand(rcID, cmdType, tParams)
    --【测试部分 ———— 开始】--
    --cmdType="Slave_SET_MODE"
	--cmdType="Slave_GET_STATUS"
    --tParams["SETMODE"]=1
    --gBoxAddress=1
	--【测试部分 ———— 结束】--
    local ARR_CMD={}
    --ARR_CMD[1]=string.format("%X",gBoxAddress)
	local tempString=string.format("%X",gBoxAddress)
	tempString=string.rep("0", 2-string.len(tempString))..tempString
    ARR_CMD[1]=tempString
    local multiNum=0
    local offset=0    

    -- 设置类命令
    if(string.find(cmdType, "Slave_SET")~=nil) then
		  gPreRC_SET=rcID --保存RC编号
		  multiNum=3
		ARR_CMD[2]="06"
		if(cmdType=="Slave_SET_TEMPERATURE") then --设置设定温度
			--01 06 07 D5 00 C8 98 d0   20°
			--01 06 07 D5 00 A0 99 3e   16°
			offset=2
			--温度乘以10后转为十六进制
			tempString=string.format("%X",tonumber(tParams["SETPOINT"])*10)
			tempString=string.rep("0", 4-string.len(tempString))..tempString
			ARR_CMD[5]=string.sub(tempString,1,2)
			ARR_CMD[6]=string.sub(tempString,3)
		elseif(cmdType=="Slave_SET_MODE_HVAC") then --设置运转模式
			--01 06 07 D4 00 00 c8 86   --送风
			--01 06 07 D4 00 01 09 46   --炽热
			--01 06 07 D4 00 02 49 47   --制冷
			offset=1
			ARR_CMD[5]="00"
			tempString=tostring(tParams["MODE"])
			if(tempString=="Heat") then
				ARR_CMD[6]="01"
			elseif(tempString=="Cool") then
				ARR_CMD[6]="02"
			else
				ARR_CMD[6]="00"
			end
		elseif(cmdType=="Slave_SET_MODE") then --设置开关及风量
			--01 06 07 D0 10 61 45 6f   --开-低风速
			--01 06 07 D0 50 61 74 af   --开-高风速
			--01 06 07 D0 10 60 84 af   --关-低风速
			--01 06 07 D0 50 60 b5 6f   --关-高风速

			offset=0
			--风速
			if(tostring(tParams["MODE"])=="Low") then
				ARR_CMD[5]="10"
			else
				ARR_CMD[5]="50"
			end
			--开/关
			if(tostring(tParams["STATUS"])=="On") then
				ARR_CMD[6]="61"
			else
				ARR_CMD[6]="60"
			end
		end
    elseif(string.find(cmdType, "Slave_GET")~=nil) then --获取当前所有状态（开/关、温度、当前设置温度）
			gPreRC_GET=rcID --保存RC编号
		  multiNum=6
			ARR_CMD[2]="04"
		if(cmdType=="Slave_GET_STATUS") then --获取当前所有状态（开/关、温度、当前设置温度）
			-- 01 04 07 D6 00 02 91 47
			-- D6 开关状态、低高风
			-- D7 室内机运转模式
			-- D8 设定温度
			-- DA 室内温度
			ARR_CMD[5]="00"
			ARR_CMD[6]="06"
		elseif(cmdType=="Slave_GET_TEMPERATURE_RANGE") then -- 获取室内机室内温度设置范围
			-- 01 04 03 ec 00 02 b0 7a    --冷
			-- 01 04 03 ed 00 02 e1 ba    --热
			offset=-1000
			ARR_CMD[5]="00"
			ARR_CMD[6]="06"
		end
    end

    --设置起始地址
    print("rcID:"..rcID..";multiNum:"..multiNum..";offset:"..offset)
    tempString=string.format("%X",2000+(rcID-1)*multiNum+offset)
    tempString=string.rep("0", 4-string.len(tempString))..tempString
    ARR_CMD[3]=string.sub(tempString,1,2)
    ARR_CMD[4]=string.sub(tempString,3)
    --将命令转换为字符串形式
    local cmd=joinCmdArr(ARR_CMD)
    --计算CRC
    local crcStr=string.format("%X",calcCRC(tohex(cmd)))
    crcStr=string.rep("0", 4-string.len(crcStr))..crcStr
    --包含CRC校验位的串口命令
    cmd=string.format("%s %s %s",cmd, string.sub(crcStr,3), string.sub(crcStr,1,2))
    --发送串口命令
    print("Maste执行命令："..cmd)
    C4:SendToSerial(gSerialId, tohex(cmd))
end

--[[
    由串口接收数据
]]
function ReceivedFromSerial(idBinding, strData)
    if(gAuthed~=true) then
	   print("权限验证失败")
	   return
    end
    --print("【Master】ReceivedFromSerial[" .. idBinding.. "]["..strData.."]")
    local len=#strData

    if(len>0) then
	   local ARR_Data={}
	   local crcArr={}

	   if(gDataCount>20) then
		  gDataCount=0
		  return
	   end
	   --print("gDataCount:"..gDataCount)
	   if(gDataCount==0) then --初次收到
		  --print("初次收到")
		  local tmpNum=tonumber(strData:byte(1))
		  if(tmpNum~=gBoxAddress) then--只处理发给自己的
			 --print("return 只处理发给自己的")
			 return
		  end

		  tmpNum=tonumber(strData:byte(2)) --第1包，根据[2]判断命令类型
		  --print("tmpNum 命令类型:"..tmpNum)
		  gDataCount=0 --重置计数

		  if(tmpNum==4) then --【获取状态】的响应
			 ARR_BUFFER_GET={}
			 ARR_BUFFER_CRC={}
			 --print("填充缓存区")
			 fillBuffer(strData) --填充缓存区
		  elseif(tmpNum==6) then --【设置】响应
			 --print("【设置】响应开始")
			 gIsWaiting=false
			 gDataCount=8
			 for i=1,len do
				if(i<=6) then				    
				    ARR_Data[i]=string.format("%X",tonumber(strData:byte(i)))
				    ARR_Data[i]=string.rep("0", 2-string.len(ARR_Data[i]))..ARR_Data[i]
				
				    --ARR_Data[i]=string.format("%X",tonumber(strData:byte(i)))
				    --ARR_Data[i]=string.rep("0", 2-string.len(ARR_Data[i]))..ARR_Data[i]
				else
				    crcArr[i-6]=tonumber(strData:byte(i))
				end
			 end
		  else
			 return
		  end
	   else --非初次收到
		  --print("非初次收到")
		  if(gIsWaiting) then
			 --print("继续填充缓存区")
			 fillBuffer(strData)
		  end

		  if(gIsWaiting~=true) then --如果数据完整，则转存数据
			 ARR_Data={}
			 --ARR_BUFFER_GET={}
			 --ARR_BUFFER_CRC={}
			 for i=1,#ARR_BUFFER_GET do
				ARR_Data[i]=ARR_BUFFER_GET[i]
				--print("ARR_Data["..i.."]:"..ARR_Data[i])
			 end
			 crcArr[1]=ARR_BUFFER_CRC[1]
			 --print("crcArr[1]:"..crcArr[1])
			 crcArr[2]=ARR_BUFFER_CRC[2]
			 --print("crcArr[2]:"..crcArr[2])
		  end
	   end

	   --[[=============== 数据处理 ===============]]
	   if(gIsWaiting==false) then
		  --print("准备CRC校验:"..#ARR_Data)

		  for i=1,#ARR_Data do
			 --print("ARR_Data["..i.."]:"..tostring(ARR_Data[i]))
		  end
		  for i=1,#crcArr do
			 --print("crcArr["..i.."]:"..tostring(crcArr[i]))
		  end

		  --将命令转换为字符串形式
		  local tmpCmd=joinCmdArr(ARR_Data)
		  --print("tmpCmd:"..tmpCmd)
		  --print("arrData length:"..#ARR_Data)
		  --计算CRC
		  local crcReult=string.format("%X",calcCRC(tohex(tmpCmd)))
		  crcReult=string.rep("0", 4-string.len(crcReult))..crcReult
		  --print("crcReult:"..crcReult)
		  --包含CRC校验位的串口命令

		  ----------验证CRC----------
		  local crcstr_1=string.format("%X",crcArr[1])
		  crcstr_1=string.rep("0", 2-string.len(crcstr_1))..crcstr_1
		  local crcstr_2=string.format("%X",crcArr[2])
		  crcstr_2=string.rep("0", 2-string.len(crcstr_2))..crcstr_2

		  if(crcstr_1~=string.upper(string.sub(crcReult,3)) or crcstr_2~=string.upper(string.sub(crcReult,1,2))) then
			 gDataCount=0 --计数器清0
			 print("CRC验证失败")
			 return --放弃CRC校验错误的数据
		  end
		  --print("CRC验证通过")

		  ----------命令转换为数字----------
		  --print("gDataCount:"..gDataCount)
		  for i=1,gDataCount-2 do
			 --print("ARR_Data["..i.."]:"..ARR_Data[i])
			 ARR_Data[i]=tonumber(string.format("%d","0x"..ARR_Data[i]))
		  end
		  
		  for i=1,gDataCount-2 do
			 --print("ARR_Data["..i.."]:"..ARR_Data[i])
			 --ARR_Data[i]=tonumber(string.format("%d","0x"..ARR_Data[i]))
		  end
		  
		  ----------填充返回给RC的命令和参数----------
		  local toID=0
		  local cmd=""
		  local toParam={}
		  for i=1,gDataCount-2 do
			 --print("--print(ARR_Data["..i.."]):"..ARR_Data[i])
		  end
		  gDataCount=0

		  --print("填充返回命令和参数 —— 开始")

		  if(ARR_Data[2]==4) then --【获取状态】的响应
			 for k,v in pairs(MAP_RC_Binding) do
				--print("k:"..k.."，v:"..v)
			 end

			 toParam["RCID"]=gPreRC_GET
			 print("gPreRC_GET:"..gPreRC_GET)

			 for i=1,10 do
				--print("MAP_RC_Binding["..i.."]:"..MAP_RC_Binding[i]);
			 end
			 toID=MAP_RC_Binding[gPreRC_GET]			 
			 --toID=MAP_RC_Binding[math.modf((ARR_Data[3]*256+ARR_Data[4]-2000)/6)+1]
			 --print(toID)
			 gPreRC_GET=0
			 cmd="STATUS_REFRESH"
			 
				
			--=====================
			 --【风速】--
			local tmpA,tmpB=math.modf(ARR_Data[4]/16)
			 if(bit._and(nil,tmpA,5)>0) then
				toParam["FAN_SPEED"]="High"
			else
				toParam["FAN_SPEED"]="Low"
			end
			--=====================
			 --【运转/停止状态】--
			 if(bit._and(nil,ARR_Data[5],1)>0) then
				toParam["STATUS"]="On"
			else
				toParam["STATUS"]="Off"
			end
			--==================
			tmpA,tmpB=math.modf(ARR_Data[6]/(16*4))

			 --【运转状态】--
			 --print("tmpA:"..tmpA..";tmpB:"..tmpB)
			 if(bit._and(nil,ARR_Data[6],1)>0) then
				toParam["RUN_STATUS"]="Heat"
			elseif(bit._and(nil,ARR_Data[6],2)>0) then
				toParam["RUN_STATUS"]="Cool"
			else
				toParam["RUN_STATUS"]="Wind"
			end

			 --【冷热选择权】--
			 if(tmpA==1) then
				toParam["CAN_MODE"]="False"
			elseif(tmpA==2) then
				toParam["CAN_MODE"]="True"
			else
				toParam["CAN_MODE"]="--"
			end

			--=====================
			 --【运转模式】--
			 if(bit._and(nil,ARR_Data[7],1)>0) then
				toParam["RUN_MODE"]="Heat"
			elseif(bit._and(nil,ARR_Data[7],2)>0) then
				toParam["RUN_MODE"]="Cool"
			elseif(bit._and(nil,ARR_Data[7],3)>0) then
				toParam["RUN_MODE"]="Auto"
			elseif(bit._and(nil,ARR_Data[7],7)>0) then
				toParam["RUN_MODE"]="Wet"
			else
				toParam["RUN_MODE"]="Wind"
			end
			--=====================

			 --【设定温度】--
			 toParam["TEMPERATURE_TARGET"]=ARR_Data[8]*256+ARR_Data[9]
			--=====================

			 --【实际温度】--
			 toParam["TEMPERATURE"]=ARR_Data[12]*256+ARR_Data[13]
			--=====================
			local tmpIntData=tonumber(ARR_Data[14])
			 --【温度传感器异常】
			 if(bit._and(nil,tmpIntData,1)>0) then
				toParam["TEMPERATURE_ERROR"]="True"
			 else
				toParam["TEMPERATURE_ERROR"]="False"
			 end
			 --【数据已接受】
			 if(bit._and(nil,tmpIntData,8)>0) then
				toParam["DATA_RECIEVED"]="True"
			 else
				toParam["DATA_RECIEVED"]="False"
			 end
			--=====================

		  elseif(ARR_Data[2]==6) then --【设置参数】的响应
			 --print("设置响应")
			 cmd="ACTION_RESPONSE"
			 --print("设置响应0："..gPreRC_SET)
			 --print("设置响应1："..ARR_Data[3]..";"..ARR_Data[4])
			 --print("设置响应2："..math.modf((ARR_Data[3]*256+ARR_Data[4]-2000)/3))
			 --print("设置响应3："..math.modf((ARR_Data[3]*256+ARR_Data[4]-2000)/3)+1)
			 --print("设置响应4："..toID)
			 toID=MAP_RC_Binding[math.modf((ARR_Data[3]*256+ARR_Data[4]-2000)/3)+1]
			 --暂不做其他处理，将结果返回RC
			 toParam["RESULT"]="OK"
			 toParam["RCID"]=gPreRC_SET
			 gPreRC_SET=0
		  end

		  if(toID~=0) then
			 print("发送命令："..toID.."==【"..toParam["RCID"].."】"..cmd)
			 
			for key, value in pairs(toParam) do
				--print("key:"..key..";value:"..value)
			end
			 C4:SendToProxy(toID, cmd, toParam)
		  end
	   end
    end
end

--[[
    填充缓存区
]]
function fillBuffer(strData)
    local len=#strData
    local max=gDataCount+len
    --print("填充前gDataCount:"..gDataCount)
    if(max>40) then
	   max=40
    end
    
    for i=1,len do
	   --print("data["..i.."]:"..tonumber(strData:byte(i)));
    end
    
    for i=1,len do
	   gDataCount=gDataCount+1
	   
	   if(gDataCount<=17-2) then
		  --ARR_BUFFER_GET[gDataCount]=tonumber(strData:byte(i))
		  --print("填充数据："..i.."_"..string.format("%X",tonumber(strData:byte(i))))
		  ARR_BUFFER_GET[gDataCount]=string.format("%X",tonumber(strData:byte(i)))
		  ARR_BUFFER_GET[gDataCount]=string.rep("0", 2-string.len(ARR_BUFFER_GET[gDataCount]))..ARR_BUFFER_GET[gDataCount]
		  --print("填充数据："..i)
		  --print("填充后数据："..i.."_"..tonumber(ARR_BUFFER_GET[gDataCount]))		  
	   else
		  ARR_BUFFER_CRC[gDataCount-15]=tonumber(strData:byte(i))
		  --print("填充数据CRC："..i.."_"..ARR_BUFFER_CRC[gDataCount-15])
	   end	   
    end
    
	   if(gDataCount==17) then	   
		  gIsWaiting=false
	   else
		  gIsWaiting=true
	   end

    --print("填充后gDataCount:"..gDataCount)
    if(gIsWaiting) then
	   --print("填充后gIsWaiting:true")
    else
	   --print("填充后gIsWaiting:false")
    end

    --print("填充后ARR_BUFFER_GET:"..#ARR_BUFFER_GET)
end

--[[
    计算CRC16
]]
function calcCRC(str)
    local crc;

    local function initCrc()
	   crc = 0xffff;
    end

    local function updCrc(byte)
	   crc = bit:_xor(crc, byte);
	   for i=1,8 do
		  local j = bit:_and(crc, 1);
		  crc = bit:_rshift(crc, 1);

		  if j ~= 0 then
			 crc = bit:_xor(crc, 0xA001);
		  end
	   end
    end

    local function getCrc(str)
	   initCrc();
	   for i = 1, #str do
		  --print("a==========a")
		  ----hexdump(tohex(str:byte(i)))
		  ----hexdump(tohex(string.format("%#x",str:byte(i))))
		  updCrc(str:byte(i));
	   end
	   return crc;
    end
    return getCrc(str);
end

--[[
    组合命令数组
]]
function joinCmdArr(arr)
    local cmd=""
    local aLen=#arr;
    for i=1, aLen do
	  --print(arr[i])
	  cmd=cmd..arr[i].." "
    end

    if(string.len(cmd)>0) then
	   cmd=string.sub(cmd,0,-2)
    end

    return cmd
end

--[[=================================================================================================]]--

--[[
    验证是否具有权限
]]
function checkAuthorization()
    local md5Helper=require("md5Helper")
    local stringToBeEndcode="~B5^"..string.upper(C4:GetUniqueMAC()).."%19lou!DAIKIN_TIELING";
    local mac=string.upper(md5Helper.sumhexa(stringToBeEndcode))
    --print("checkAuthorization_mac:"..mac)
    --print("checkAuthorization_gAuthCode:"..gAuthCode)
    --print("checkAuthorization:"..mac==gAuthCode)
    gAuthed=mac==gAuthCode
    if(gAuthed) then
	   --print("验证通过")
	   C4:UpdateProperty("Security State","验证通过")
    else
	   --print("验证失败")
	   C4:UpdateProperty("Security State","验证失败")
    end
end

--[[
    属性变更事件
]]
function OnPropertyChanged(strProperty)
    --print("OnPropertyChanged(" .. strProperty .. ") changed to: " .. tostring(Properties[strProperty]))
    local prop = Properties[strProperty]
    --print(strProperty.."变更3")

    if (strProperty == "Debug Mode") then
	   if (prop == "Off") then
		  return
	   end

	   generateSerialCommand(1, "", {})

    --=============================================================
    elseif (strProperty == "Auth Code") then
	   gAuthCode = string.upper(getStringProperty('Auth Code'))
	   --gTestSERIAL_BINDING_ID=gBoxAddress
	   checkAuthorization()
	   --print("Box Address变更为：".. gBoxAddress)
    --=============================================================
    elseif (strProperty == "Box Address") then
	   gBoxAddress = getStringProperty('Box Address')
	   --gTestSERIAL_BINDING_ID=gBoxAddress

	   --print("Box Address变更为：".. gBoxAddress)
    --=============================================================
    elseif (strProperty == "Cmd ID") then
	   gCmdID = getIntProperty('Cmd ID')

	   --print("Cmd ID变更为：".. gCmdID)
    --=============================================================
    end

    --gDbgTimer = C4:AddTimer(45, "MINUTES")
end
































































