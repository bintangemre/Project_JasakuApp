import { Response } from "express";
import { OrdersService } from "./orders.service";
import { successResponse, errorResponse } from "../../utils/response";

const createOrder = async (req: any, res: Response) => {
    try {        const { providerId, serviceId, pricingTypeId, quantity, description, workDate, address, lat, lng } = req.body;
        const customerId = req.user.id;
        const ordersService = new OrdersService();
        const result = await ordersService.createOrder({
            customerId,
            providerId,
            serviceId,
            pricingTypeId,  
            quantity,
            description,
            workDate,
            address,
            lat,
            lng
        });
        return successResponse(res, result, 'Order berhasil dibuat', 201);
    }
    catch (err: any) {
        return errorResponse(res, err.message);
    }
};

export { createOrder };
