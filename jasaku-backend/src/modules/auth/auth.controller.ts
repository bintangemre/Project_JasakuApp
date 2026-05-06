import { Response } from "express";
import { AuthService } from "./auth.service";
import { successResponse, errorResponse } from "../../utils/response";
import { register } from "module";

const registerCustomer = async (req: any, res: Response) => {
  try {
    const { email, password, role, name, phone, gender, birthDate } = req.body;   
    const authService = new AuthService();
    const result = await authService.registerCustomer(email, password, name, phone, gender, birthDate);
    return successResponse(res, result, 'Registrasi berhasil', 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const registerProvider = async (req: any, res: Response) => {
  try {
    const { full_name, nickname, email, password, phone, birthDate, gender, address, domicile, profile_photo, ktp_photo, selfie_photo } = req.body;
    const authService = new AuthService();
    const result = await authService.registerProvider(full_name, nickname, email, password, phone, birthDate, gender, address, domicile, profile_photo, ktp_photo, selfie_photo);
    return successResponse(res, result, 'Registrasi provider berhasil, silakan upload dokumen', 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const registerAdmin = async (req: any, res: Response) => {
  try {
    const { email, password, name, phone } = req.body;  
    const authService = new AuthService();
    const result = await authService.registerAdmin(email, password, name, phone);
    return successResponse(res, result, 'Registrasi admin berhasil', 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const login = async (req: any, res: Response) => {
  try {
    const { email, password } = req.body;
    const authService = new AuthService();
    const result = await authService.login(email, password);
    return successResponse(res, result, 'Login berhasil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }   
};

export { registerCustomer, registerProvider, registerAdmin, login };