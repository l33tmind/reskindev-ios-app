<?php
// ১. সকল PHP এরর ডিসপ্লে বন্ধ করা এবং এরর রিপোর্টিং বন্ধ করা (HTML আউটপুট রোধ করতে)
error_reporting(0);
ini_set('display_errors', 0);

// ২. JSON হেডার সেট করা
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

// ৩. CORS প্রিলেক্ট (Preflight) হ্যান্ডেল করা
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$target_dir = "uploads/";

// ৪. ডিরেক্টরি চেক এবং তৈরি
if (!file_exists($target_dir)) {
    if (!mkdir($target_dir, 0777, true)) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Failed to create uploads directory."]);
        exit;
    }
}

// ৫. রাইট পারমিশন চেক
if (!is_writable($target_dir)) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Uploads directory is not writable. Check permissions (chmod 777 uploads)."]);
    exit;
}

// ৬. ফাইল আপলোড করা হয়েছে কি না চেক
if (!isset($_FILES["image"])) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "No image file uploaded. Key 'image' missing."]);
    exit;
}

$file = $_FILES["image"];

// ৭. ফাইলের এরর চেক
if ($file['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "PHP Upload Error Code: " . $file['error']]);
    exit;
}

$imageFileType = strtolower(pathinfo($file["name"], PATHINFO_EXTENSION));
$newFileName = time() . '_' . bin2hex(random_bytes(8)) . '.' . $imageFileType;
$target_file = $target_dir . $newFileName;

// ৮. ইমেজ ফাইল কি না চেক
$check = getimagesize($file["tmp_name"]);
if($check === false) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "File is not an image."]);
    exit;
}

// ৯. ফাইল সাইজ চেক (৫ এমবি লিমিট)
if ($file["size"] > 5000000) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "File is too large (max 5MB)."]);
    exit;
}

// ১০. অ্যালাউড ফরম্যাট চেক
$allowed = ["jpg", "png", "jpeg", "gif", "webp"];
if(!in_array($imageFileType, $allowed)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Only JPG, JPEG, PNG, WEBP & GIF are allowed."]);
    exit;
}

// ১১. ফাইল মুভ করা
if (move_uploaded_file($file["tmp_name"], $target_file)) {
    $protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? "https" : "http";
    $host = $_SERVER['HTTP_HOST'];
    $script_path = dirname($_SERVER['SCRIPT_NAME']);
    $script_path = rtrim($script_path, '/\\') . '/';

    $url = $protocol . "://" . $host . $script_path . $target_file;

    http_response_code(200);
    echo json_encode(["status" => "success", "url" => $url]);
} else {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Move uploaded file failed. Check server permissions."]);
}
?>
