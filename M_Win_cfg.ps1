$config = @{
    Services = @(
        @{ ID="11"; Name="Web Service";   Port=9999;  Key="web";      StopID="21"; LogID="81" }
        @{ ID="12"; Name="WAS Service";   Port=8888;  Key="was";      StopID="22"; LogID="82" }
        @{ ID="13"; Name="Web Agent";     Port=18001; Key="webAgent"; StopID="23"; LogID="83" }
        @{ ID="14"; Name="WAS Agent";     Port=18002; Key="wasAgent"; StopID="24"; LogID="84" }
        @{ ID="15"; Name="Lena Manager";  Port=7700;  Key="manager";  StopID="25"; LogID="85" }
        @{ ID="16"; Name="DB Service";    Port=5001;  Key="db";       StopID="26"; LogID="86" }
    )
    Paths = @{
        Win = @{
            web      = @{ start="d:\engn001\lenaw\1.3\bin\start_service.bat"; stop="d:\engn001\lenaw\1.3\bin\stop_service.bat"; log="d:\logs001\lenaw\node\weblog.log" }
            was      = @{ start="d:\engn001\lena\1.3\bin\start_service.sh";   stop="d:\engn001\lena\1.3\bin\stop_service.sh";   log="d:\logs001\lena\node\weblog.log" }
            webAgent = @{ start="d:\engn001\lenaw\1.3\bin\start_agent.sh";   stop="d:\engn001\lenaw\1.3\bin\stop_agent.sh";    log="d:\logs001\lenaw\node\weblog.log" }
            wasAgent = @{ start="d:\engn001\lena\1.3\bin\start_agent.sh";    stop="d:\engn001\lena\1.3\bin\stop_agent.sh";    log="d:\logs001\lena\node\weblog.log" }
            manager  = @{ start="d:\engn001\lenaw\1.3\bin\manager.bat";      stop="d:\engn001\lenaw\1.3\bin\stop_manager.bat"; log="d:\logs001\lenaw\node\weblog.log" }
            db       = @{ start="echo DB Start"; stop="echo DB Stop"; log="d:\logs001\tomcat\log.log" }
        }
        Lin = @{
            web      = @{ start="/engn001/lenaw/1.3/bin/start.sh";        stop="/engn001/lenaw/1.3/bin/stop.sh";        log="/logs001/lenaw/node/weblog.log" }
            was      = @{ start="/engn001/lena/1.3/bin/start.sh";         stop="/engn001/lena/1.3/bin/stop.sh";         log="/logs001/lena/node/weblog.log" }
            webAgent = @{ start="/engn001/lenaw/1.3/bin/start_agent.sh";  stop="/engn001/lenaw/1.3/bin/stop_agent.sh";  log="/logs001/lenaw/node/weblog.log" }
            wasAgent = @{ start="/engn001/lena/1.3/bin/start_agent.sh";   stop="/engn001/lena/1.3/bin/stop_agent.sh";   log="/logs001/lena/node/weblog.log" }
            manager  = @{ start="/engn001/lenaw/1.3/bin/start_manager.sh"; stop="/engn001/lenaw/1.3/bin/stop_manager.sh"; log="/logs001/lenaw/node/weblog.log" }
            db       = @{ start="echo DB Start"; stop="echo DB Stop"; log="/logs001/tomcat/log.log" }
        }
    }
}
