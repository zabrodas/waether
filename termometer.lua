node.egc.setmode(node.egc.ALWAYS)

if adc.force_init_mode(adc.INIT_ADC) then
    node.restart()
end

function on_wifi_connected(SSID,BSSID,channel)
    print("WiFi connected to:",SSID,BSSID,channel)
end
function on_wifi_disconnected(SSID,BSSID,reason)
    print("WiFi disconnected from:",SSID,BSSID,reason)
end
function on_wifi_got_ip(IP,netmask,gateway)
    print("WiFi got IP:",IP,netmask,gateway)
end

weatherRequest="https://api.darksky.net/forecast/062203217cbe6cc8558d187d49692b0c/59.934945,30.373961?exclude=minutely,hourly,daily,alerts,flags&units=si"
weatherRequest="http://andrey-zabrodin.net/weather-nv395b.php"

requestTimer=tmr.create()
weatherErrCnt=0

wifi.setmode(wifi.STATION);
station_cfg={}
station_cfg.ssid="gzabrodina"
station_cfg.pwd="pusya756nadya"
station_cfg.auto=true
station_cfg.save=true
station_cfg.connected_cb=on_wifi_connected
station_cfg.disconnected_cb=on_wifi_disconnected
station_cfg.got_ip_cb=on_wifi_got_ip
wifi.sta.config(station_cfg)

function onWeatherReceived(code,data,headers)
    print("heap:",node.heap())
    print("Weather:",code,data,headers)
    local ok,wd=pcall(sjson.decode,data)
    local temp=nil
    local windBearing=nil
    local windSpeed=nil
    if ok then 
        for k,v in pairs(wd) do print(k,v) end
        if wd.currently~=nil and wd.currently.temperature~=nil then
            temp=tonumber(wd.currently.temperature)
        end
        if wd.currently~=nil and wd.currently.windBearing~=nil then
            windBearing=tonumber(wd.currently.windBearing)
        end
        if wd.currently~=nil and wd.currently.windSpeed~=nil then
            windSpeed=tonumber(wd.currently.windSpeed)
        end
    else
        print("Unformatted data:",data)
    end
    print("temp=",temp)
    if temp~=nil and temp>=motorScaleMinTemp and temp<=motorScaleMaxTemp then
        weatherErrCnt=0
        indicateTemp(temp)
        if windBearing~=nil and windSpeed~=nil then
            indicateWind(windBearing,windSpeed)
        end
        requestTimer:register(60000*5, tmr.ALARM_SINGLE, getWeather)
    else
        if weatherErrCnt<10 then
            weatherErrCnt=weatherErrCnt+1
        else
            indicateTemp(motorScaleMaxTemp)
        end
        requestTimer:register(10000, tmr.ALARM_SINGLE, getWeather)
    end
    print("weatherErrCnt=",weatherErrCnt)
    requestTimer:start()
end

function getWeather()
    print("heap:",node.heap())
    http.get(weatherRequest,nil,onWeatherReceived)
end

motorSignals={
    gpio.HIGH,gpio.LOW ,gpio.HIGH,gpio.LOW ,
    gpio.LOW ,gpio.HIGH,gpio.HIGH,gpio.LOW ,
    gpio.LOW ,gpio.HIGH,gpio.LOW ,gpio.HIGH,
    gpio.HIGH,gpio.LOW ,gpio.LOW ,gpio.HIGH
}
motorNumSteps=4

motorStepsPerRevolution=128*16
motorStepsPerAngleGrad=motorStepsPerRevolution/360
motorScaleMinTemp=-40
motorScaleMaxTemp=40
motorScaleAngle=270
motorStepsInScale=motorScaleAngle*motorStepsPerAngleGrad
motorStepsPerGradTemp=motorStepsInScale/(motorScaleMaxTemp-motorScaleMinTemp)

motor1={
    pins={4,3,2,1},
    delay=1000
}
motor2={
    pins={8,7,6,5},
    delay=3000
}    
    
function initMotor(motor)
    for i=1,4 do
        gpio.mode(motor.pins[i], gpio.OUTPUT)
    end
    motor.step=1
    motor.pos=0
    motorStart(motor)
    motorStop(motor)
end
function motorInitPos(motor,pos)
    motor.pos=pos
end    

function motorWriteState(motor)
    for i=1,4 do
--        print( (motorStep-1)*4+i)
        gpio.write(motor.pins[i], motorSignals[(motor.step-1)*4+i])
    end
    tmr.delay(motor.delay)
end
function motorStart(motor)
    motorWriteState(motor)
end
function motorStop(motor)
    for i=1,4 do
        gpio.write(motor.pins[i], gpio.LOW)
    end
    tmr.delay(motor.delay)
end
function motorNext(motor)
    motorStart(motor)
    motor.step=motor.step+1
    if motor.step>motorNumSteps then
        motor.step=1
    end
    motorWriteState(motor)
    motor.pos=motor.pos+1
end
function motorPrev(motor)
    motorStart(motor)
    motor.step=motor.step-1
    if motor.step<1 then
        motor.step=motorNumSteps
    end
    motorWriteState(motor)
    motor.pos=motor.pos-1
end
function motorMoveTo(motor,pos)
    motorStart(motor)
    while pos>motor.pos do
        motorNext(motor)
    end
    while pos<motor.pos do
        motorPrev(motor)
    end
    motorStop(motor)
    print("motorPos=",motor.pos)
end
function motorMoveRel(motor,steps)
    motorMoveTo(motor,steps+motor.pos)
    motorNormalizePos(motor)
end
function motorNormalizePos(motor)
    while motor.pos>=motorStepsPerRevolution do
        motor.pos=motor.pos-motorStepsPerRevolution
    end
    while motor.pos<0 do
        motor.pos=motor.pos+motorStepsPerRevolution
    end
end

function tempToPos(grad)
    return grad*motorStepsPerGradTemp
end
function indicateTemp(grad)
    motorMoveTo(motor1,tempToPos(grad))
end
function tempHome()
    indicateTemp(motorScaleMinTemp-motorScaleMaxTemp)
    motorInitPos(motor1,tempToPos(motorScaleMinTemp-1.5))
    indicateTemp(0)
end

function windDirectionToPos(direction)
    return motorStepsPerAngleGrad*direction
end
function windPosToDirection(pos)
    return pos/motorStepsPerAngleGrad
end

windDisk1Angle=0
windDisk2Angle=0

function windHome()
    motorInitPos(motor2,0)
    motorStart(motor2)
    for i=1,motorStepsPerRevolution*1.1/2 do
        motorPrev(motor2)
    end
    local s1=0
    local s2=0
    for i=1,motorStepsPerRevolution do
        v=adc.read(0)
        print("adc=",v)
        if v>s1 then
            s1=v
            s2=motor2.pos
        end
        motorPrev(motor2)
    end
    local homePos=s2
    print("windHomePos=",homePos)
    motorMoveTo(motor2,homePos-motorStepsPerRevolution)
    motorStop(motor2)
    motorInitPos(motor2,0)
    windDisk1Angle=0
    windDisk2Angle=0
end

function normAngle180(d)
    while d>=180 do
        d=d-360
    end
    while d<-180 do
        d=d+360
    end
    return d
end
function normAngle360(t)
    while t>=360 do
        t=t-360
    end
    while t<0 do
        t=t+360
    end
    return t
end

function windMoveDisks(a1,a2)
    print(windDisk1Angle,"->",a1,",",windDisk2Angle,"->",a2)
    local d1=normAngle180(a1-windDisk1Angle)
    local d2
    print("d1=",d1)
    if d1~=0 then
        if d1<0 then
            d2=normAngle360(a1-windDisk2Angle)-360
            print("d2=",d2)
            motorMoveRel(motor2,windDirectionToPos(d2))
            windDisk2Angle=windPosToDirection(motor2.pos)
            windDisk1Angle=windDisk2Angle
        else
            d2=normAngle360(a1+180-windDisk2Angle)
            print("d2=",d2)
            motorMoveRel(motor2,windDirectionToPos(d2))
            windDisk2Angle=windPosToDirection(motor2.pos)
            windDisk1Angle=windDisk2Angle-180
        end
    end
    d2=normAngle180(a2-windDisk2Angle)
    print("d2=",d2)
    motorMoveRel(motor2,windDirectionToPos(d2))
    windDisk2Angle=windPosToDirection(motor2.pos)
    print(windDisk1Angle,",",windDisk2Angle)
end

maxWind=12

function windLinear(x)
    if x<0 then 
        return 0
    end
    if x>12
        return 90
    end
    local a=86.76929*(1-1/(x*0.26546+1))+x*2.01758
    if a<0 then
        return 0
    end
    if a>90 then
        return 90
    end
    return a
end

function indicateWind(dir,speed)
    if speed<0 then
        speed=0
    end
    if speed>maxWind then
        speed=maxWind
    end
    local da=90-windLinear(speed)
    local a1=dir-da
    local a2=dir+da
    print("wind:",dir,",",speed,"->",a1,",",a2)
    windMoveDisks(a1,a2)    
end

initMotor(motor1)
initMotor(motor2)
tempHome()
windHome()

requestTimer:register(10000, tmr.ALARM_SINGLE, getWeather)
requestTimer:start()
