Start-PodeServer {
    # Импортируем модуль для работы с AD
    import-module ActiveDirectory

    # Запускаем сервер на http://localhost:8080
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Включаем возможность рендеринга и использования .pode файлов
    Set-PodeViewEngine -Type Pode

    # Маршрут для главной страницы
    Add-PodeRoute -Method get -Path '/change-attribute' -ScriptBlock {

        # Получаем информацию о пользователе
        if ($login = $WebEvent.Query["login"]) {
            try {
                $phone_number = get-aduser $login -Properties telephoneNumber | select telephoneNumber -ExpandProperty telephoneNumber
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityResolutionException] {
                $message = "Пользователь $login не найден"
            }
        }
        # Указываем, что мы обращаемся к шаблону change-attribute.pode в директории /views
        # и передаём в шаблон данные
        Write-PodeViewResponse -Path 'change-attribute' -Data @{ "login" = $login; "phone" = $phone_number; "message" = $message }
    }

    # Запись атрибута пользователя
    Add-PodeRoute -Method post -Path '/set-phone' -ScriptBlock {
        if (($login = $WebEvent.Data.login) -and ($phone_number = $WebEvent.Data.phone)) {
            # Изменяем номер телефона пользователя
            Get-ADUser -Identity $login | Set-ADUser -replace @{telephonenumber=$phone_number}
        }
        # Перенаправляем пользователя на главную страницу
        Move-PodeResponseUrl -Url '/change-attribute'
    }
}