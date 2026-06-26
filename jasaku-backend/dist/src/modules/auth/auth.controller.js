import { AuthService } from "./auth.service";
import { successResponse, errorResponse } from "../../utils/response";
const registerCustomer = async (req, res) => {
    try {
        const { email, password, role, name, phone, gender, birthDate } = req.body;
        const authService = new AuthService();
        const result = await authService.registerCustomer(email, password, name, phone, gender, birthDate);
        return successResponse(res, result, 'Registrasi berhasil', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const registerProvider = async (req, res) => {
    try {
        const { full_name, nickname, email, password, phone, birthDate, gender, address, domicile, profile_photo, ktp_photo, selfie_photo, services } = req.body;
        const authService = new AuthService();
        const result = await authService.registerProvider(full_name, nickname, email, password, phone, birthDate, gender, address, domicile, profile_photo, ktp_photo, selfie_photo, services);
        return successResponse(res, result, 'Registrasi provider berhasil, silakan upload dokumen', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const registerAdmin = async (req, res) => {
    try {
        const { email, password, name, phone } = req.body;
        const authService = new AuthService();
        const result = await authService.registerAdmin(email, password, name, phone);
        return successResponse(res, result, 'Registrasi admin berhasil', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        const authService = new AuthService();
        const result = await authService.login(email, password);
        return successResponse(res, result, 'Login berhasil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const loginWithGoogle = async (req, res) => {
    try {
        const { idToken } = req.body;
        const authService = new AuthService();
        const result = await authService.loginWithGoogle(idToken);
        return successResponse(res, result, 'Login dengan Google berhasil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { registerCustomer, registerProvider, registerAdmin, login, loginWithGoogle };
