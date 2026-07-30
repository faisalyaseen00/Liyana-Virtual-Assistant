class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json["access_token"],
      refreshToken: json["refresh_token"],
      tokenType: json["token_type"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "access_token": accessToken,
      "refresh_token": refreshToken,
      "token_type": tokenType,
    };
  }
}

class RegisterResponse {
  final String message;
  final String userId;

  const RegisterResponse({
    required this.message,
    required this.userId,
  });

  factory RegisterResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return RegisterResponse(
      message: json["message"],
      userId: json["user_id"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "message": message,
      "user_id": userId,
    };
  }
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "password": password,
    };
  }
}

class RegisterRequest {
  final String email;
  final String password;
  final String? fullName;

  const RegisterRequest({
    required this.email,
    required this.password,
    this.fullName,
  });

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "password": password,
      "full_name": fullName,
    };
  }
}

class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() {
    return {
      "refresh_token": refreshToken,
    };
  }
}