Start-PodeServer {

    $services = "AdobeARMservice", "bits", "spooler", "wuauserv"

    # Запускаем сервер на http://localhost:8080
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Включаем возможность рендеринга и использования .pode файлов
    Set-PodeViewEngine -Type Pode

    # Маршрут для главной страницы с таблицей
    Add-PodeRoute -Method Get -Path '/restart-services' -ScriptBlock {

        # Получаем информацию о службах
        $data = Get-Service $($using:services)

        # Указываем, что мы обращаемся к шаблону restart-services.pode в директории /views
        # и передаём в шаблон хэш-таблицу с результатом выполнения Get-Service
        Write-PodeViewResponse -Path 'restart-services' -Data @{ "services" = $data }
    }

    # Маршрут для запуска службы
    Add-PodeRoute -Method Get -Path '/start' -ScriptBlock {
        Write-Host $WebEvent.Query["name"]
        # Получаем имя службы из переданного параметра. В коде шаблона это ?name=$($service.name)
        $service_name = $WebEvent.Query["name"]

        # Проверяем, есть ли служба в списке
        if ($($using:services).Contains($service_name)) {

            # Если есть, выполняем старт службы
            Start-Service -name $service_name
            
        }

        # Перенаправляем пользователя на страницу с таблицей
        Move-PodeResponseUrl -Url '/restart-services'
    }

    # Маршрут для остановки службы
    Add-PodeRoute -Method Get -Path '/stop' -ScriptBlock {
        $service_name = $WebEvent.Query.name
        if ($($using:services).Contains($service_name)) {
            Stop-Service -name $service_name
        }
        Move-PodeResponseUrl -Url '/restart-services'
    }

    # Маршрут для перезапуска службы
    Add-PodeRoute -Method Get -Path '/restart' -ScriptBlock {
        $service_name = $WebEvent.Query.name
        if ($($using:services).Contains($service_name)) {
            Restart-Service -name $service_name
        }
        Move-PodeResponseUrl -Url '/restart-services'
    }
}