import { Response } from "express";
import { AuthRequest } from "../../middleware/auth.middleware";
import { successResponse, errorResponse } from "../../utils/response";
import { uploadToStorage } from "../../services/storage.service";

const uploadFile = async (req: AuthRequest, res: Response) => {
  try {
    const file = req.file;
    if (!file) return errorResponse(res, "File wajib diupload", 400);

    const folder = (req.body.folder as string) || "order-attachments";
    const fileUrl = await uploadToStorage(file.buffer, folder, file.originalname);
    return successResponse(res, { url: fileUrl }, "File berhasil diupload", 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export { uploadFile };
