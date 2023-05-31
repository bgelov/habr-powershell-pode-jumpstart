Start-PodeServer {

    # Рабочая директория для действий API
    $work_directory = "C:\TestFolder"
    
    # Запускаем сервер на http://localhost:8080
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Аутентификация
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'ApiKeyAuthenticate' -Sessionless -ScriptBlock {
        param($key)
        # В переменной $key будет API-ключ с которым пришёл пользователь

        # Реализуем проверку API ключей
        # Для примера будем проверять ключи обращаясь к csv файлу
        $file_with_keys = "$PSScriptRoot\api_keys.csv"
        # Ищем совпадение входящего ключа с ключом в файле
        $user = Import-Csv $file_with_keys -Delimiter ";" | where key -eq "$key"

        # Если нашли, записываем пользователя в кастомный лог возвращаем пользователя 
        if ($user) {
            Write-CustomAccessLog
            return @{ User = $user.user }
        } else {
            # Если не нашли, вернём сообщение
            return @{ Message = "Access denied!" } 
        }
    }


    # Логирование
    # Включаем requests лог
    New-PodeLoggingMethod -File -Name 'requests' -Path "$PSScriptRoot\logs" -MaxDays 30 -MaxSize 10MB | Enable-PodeRequestLogging
    # Включаем error лог
    New-PodeLoggingMethod -File -Name 'error' -Path "$PSScriptRoot\logs" -MaxDays 30 -MaxSize 10MB | Enable-PodeErrorLogging
    
    # Создаём собственный access лог
    New-PodeLoggingMethod -File -Name 'access' -Path "$PSScriptRoot\logs" -MaxDays 30 -MaxSize 10MB | Add-PodeLogger -Name 'access' -ScriptBlock {
    param($item)
        # Формат вывода параметров в файл
        return "$($item.DateTime), $($item.user)"

        # Для вывода в консоль пишем:
        # $item | out-default 
    }

    # Пишем функцию для записи в собственный лога
    function Write-CustomAccessLog($user, $message)
    {
        Write-PodeLog -Name 'access' -InputObject @{
        DateTime = $(Get-Date -Format "dd-MM-yyyy HH:mm:ss");
        user = $user.user;
        }
    }


    # Ограничение по количеству обращений
    Add-PodeLimitRule -Type IP -Values all -Limit 6 -Seconds 60


    # Запуск удаления файлов
    Add-PodeRoute -Method Delete -Path '/api/remove-logs' -Authentication 'ApiKeyAuthenticate' -ScriptBlock {
        
        # Получаем список файлов для удаления
        $files_for_delete = Get-ChildItem $using:work_directory -Recurse -Include "*.log"
        
        # Удаляем файлы
        $files_for_delete | Remove-Item -Force

        # Возвращаем список удалённых файлов
        Write-PodeJsonResponse -Value $($files_for_delete | select FullName | ConvertTo-Json)
    }

    # Получение информации о файлах
    Add-PodeRoute -Method Get -Path '/api/get-childitem' -Authentication 'ApiKeyAuthenticate' -ScriptBlock {

        # Получаем список файлов в директории
        $result = Get-ChildItem $using:work_directory -Recurse -File | select FullName | ConvertTo-Json

        # Возвращаем список в JSON
        Write-PodeJsonResponse -Value $result
    }

}

