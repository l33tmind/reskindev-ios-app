<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ==========================================
// SMTP CONFIGURATION (UPDATE THESE VALUES)
// ==========================================
$smtpHost = 'smtp.gmail.com'; // e.g. mail.reskindev.com or smtp.gmail.com
$smtpPort = 465; // 465 for SSL, 587 for TLS
$smtpUser = 'reskindevdotcom@gmail.com'; // Your email address
$smtpPass = 'ppksicfbxrlizcxb'; // Your email password
$fromEmail = 'reskindevdotcom@gmail.com'; 
$fromName = 'reskindev';
// ==========================================

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['email']) || !isset($data['orderId']) || !isset($data['status'])) {
    http_response_code(400);
    echo json_encode(["message" => "Missing required fields."]);
    exit;
}

$to = $data['email'];
$orderId = $data['orderId'];
$status = strtolower($data['status']);
$clientName = isset($data['clientName']) ? $data['clientName'] : 'Customer';
$gigTitle = isset($data['gigTitle']) ? $data['gigTitle'] : 'Service';
$packageName = isset($data['packageName']) ? $data['packageName'] : 'Standard';
$price = isset($data['price']) ? number_format((float)$data['price'], 2, '.', '') : '0.00';
$date = isset($data['date']) ? date("F j, Y", strtotime($data['date'])) : date("F j, Y");

$subject = "Order Status Update - $orderId";
$htmlContent = "";

// Base styles for the email
$styles = "
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #F9FAFB; margin: 0; padding: 40px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        .header { background-color: #111827; padding: 32px; text-align: center; }
        .header h1 { color: #ffffff; margin: 0; font-size: 28px; font-weight: 800; letter-spacing: 1px; }
        .header h1 span { color: #10B981; }
        .content { padding: 40px; color: #374151; line-height: 1.6; }
        .invoice-box { background-color: #F3F4F6; padding: 24px; border-radius: 8px; margin: 24px 0; border: 1px solid #E5E7EB; }
        .btn { display: inline-block; background-color: #10B981; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; margin-top: 24px; }
        .footer { background-color: #F3F4F6; padding: 24px; text-align: center; font-size: 13px; color: #6B7280; }
    </style>
";

if ($status === 'in_progress') {
    $subject = "Invoice & Payment Received - Order #$orderId";
    $htmlContent = "
    <!DOCTYPE html>
    <html>
    <head>$styles</head>
    <body>
        <div class='container'>
            <div class='header'>
                <h1>reskin<span>dev</span></h1>
            </div>
            <div class='content'>
                <h2>Hi {$clientName},</h2>
                <p>Thank you for your order! We have successfully received your payment. Your order is now <strong>In Progress</strong> and our team is actively working on it.</p>
                
                <h3>Invoice Details</h3>
                <div class='invoice-box'>
                    <div style='display: flex; justify-content: space-between; padding-bottom: 12px;'>
                        <span style='color: #6B7280;'>Order ID:</span>
                        <strong>#{$orderId}</strong>
                    </div>
                    <div style='display: flex; justify-content: space-between; padding-bottom: 12px;'>
                        <span style='color: #6B7280;'>Date:</span>
                        <strong>{$date}</strong>
                    </div>
                    <div style='display: flex; justify-content: space-between; padding-bottom: 12px; padding-top: 12px; border-top: 1px solid #E5E7EB;'>
                        <span style='color: #374151; width: 70%;'>{$gigTitle} ({$packageName} Package)</span>
                        <strong>\${$price}</strong>
                    </div>
                    <div style='display: flex; justify-content: space-between; padding-top: 16px; margin-top: 8px; border-top: 1px solid #E5E7EB; font-weight: 800; font-size: 18px; color: #111827;'>
                        <span>Total Paid:</span>
                        <span>\${$price}</span>
                    </div>
                </div>
            </div>
            <div class='footer'>
                &copy; " . date('Y') . " reskindev. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    ";
} else if ($status === 'completed') {
    $subject = "Order Completed - #$orderId";
    $htmlContent = "
    <!DOCTYPE html>
    <html>
    <head>$styles</head>
    <body>
        <div class='container'>
            <div class='header'>
                <h1>reskin<span>dev</span></h1>
            </div>
            <div class='content'>
                <h2>Hi {$clientName},</h2>
                <p>Great news! Your order for <strong>{$gigTitle}</strong> has been successfully completed.</p>
                
                <div style='background-color: #D1FAE5; color: #065F46; padding: 16px; border-radius: 8px; margin: 24px 0; border: 1px solid #A7F3D0; text-align: center;'>
                    <h3 style='margin: 0;'>All Complete!</h3>
                    <p style='margin: 8px 0 0 0;'>Your final delivery is ready.</p>
                </div>

                <p>You can now log into your account to access your premium files, source code, or gallery.</p>
            </div>
            <div class='footer'>
                &copy; " . date('Y') . " reskindev. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    ";
} else {
    $statusText = ucfirst($status);
    $htmlContent = "
    <!DOCTYPE html>
    <html>
    <head>$styles</head>
    <body>
        <div class='container'>
            <div class='header'>
                <h1>reskin<span>dev</span></h1>
            </div>
            <div class='content'>
                <h2>Hi {$clientName},</h2>
                <p>Your order (<strong>#{$orderId}</strong>) status has been updated to: <strong>{$statusText}</strong>.</p>
                <p>Thank you for choosing Hire App Developer!</p>
            </div>
            <div class='footer'>
                &copy; " . date('Y') . " reskindev. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    ";
}

function send_smtp_email($host, $port, $user, $pass, $from, $fromName, $to, $subject, $body) {
    $crlf = \"\\r\\n\";
    $timeout = 10;
    $ssl = ($port == 465) ? 'ssl://' : '';
    
    $socket = fsockopen($ssl.$host, $port, $errno, $errstr, $timeout);
    if (!$socket) return \"Connection failed: $errstr ($errno)\";

    function server_parse($socket, $expected_response) {
        $server_response = '';
        while (substr($server_response, 3, 1) != ' ') {
            if (!($server_response = fgets($socket, 256))) {
                return false;
            }
        }
        if (!(substr($server_response, 0, 3) == $expected_response)) {
            return false;
        }
        return true;
    }

    server_parse($socket, '220');

    fwrite($socket, 'EHLO ' . $host . $crlf);
    server_parse($socket, '250');

    if ($port == 587) {
        fwrite($socket, 'STARTTLS' . $crlf);
        server_parse($socket, '220');
        stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT);
        fwrite($socket, 'EHLO ' . $host . $crlf);
        server_parse($socket, '250');
    }

    fwrite($socket, 'AUTH LOGIN' . $crlf);
    server_parse($socket, '334');

    fwrite($socket, base64_encode($user) . $crlf);
    server_parse($socket, '334');

    fwrite($socket, base64_encode($pass) . $crlf);
    if (!server_parse($socket, '235')) {
        return \"Authentication failed\";
    }

    fwrite($socket, 'MAIL FROM: <' . $from . '>' . $crlf);
    server_parse($socket, '250');

    fwrite($socket, 'RCPT TO: <' . $to . '>' . $crlf);
    server_parse($socket, '250');

    fwrite($socket, 'DATA' . $crlf);
    server_parse($socket, '354');

    $headers = \"From: $fromName <$from>$crlf\";
    $headers .= \"To: <$to>$crlf\";
    $headers .= \"Subject: $subject$crlf\";
    $headers .= \"MIME-Version: 1.0$crlf\";
    $headers .= \"Content-Type: text/html; charset=UTF-8$crlf\";

    fwrite($socket, $headers . $crlf . $body . $crlf . '.' . $crlf);
    server_parse($socket, '250');

    fwrite($socket, 'QUIT' . $crlf);
    fclose($socket);
    
    return true;
}

$result = send_smtp_email($smtpHost, $smtpPort, $smtpUser, $smtpPass, $fromEmail, $fromName, $to, $subject, $htmlContent);

if ($result === true) {
    http_response_code(200);
    echo json_encode([\"message\" => \"Email sent successfully via SMTP!\"]);
} else {
    http_response_code(500);
    echo json_encode([\"message\" => \"SMTP Error: \" . $result]);
}
?>
