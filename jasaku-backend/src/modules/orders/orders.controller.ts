import { Response } from "express";
import { OrdersService } from "./orders.service";
import { successResponse, errorResponse } from "../../utils/response";

const createOrder = async (req: any, res: Response) => {
    try {        
        const { providerId, serviceId, pricingTypeId, quantity, description, workDate, address, lat, lng, attachments } = req.body;
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
            lng,
            attachments: attachments || []
        });
        return successResponse(res, result, 'Order berhasil dibuat', 201);
    }
    catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const getOrderDetails = async (req: any, res: Response) => {
    try {
        const { orderId } = req.params;
        const ordersService = new OrdersService();
        const result = await ordersService.getOrderDetails(orderId);
        if (!result) {
            return errorResponse(res, 'Order tidak ditemukan', 404);
        }
        return successResponse(res, result, 'Detail order berhasil diambil');
    }
    catch (err: any) {     
        return errorResponse(res, err.message);
    }
};

const getCustomerOrders = async (req: any, res: Response) => {
    try {
        const customerId = req.user.id;
        const ordersService = new OrdersService();
        const result = await ordersService.getCustomerOrders(customerId);
        return successResponse(res, result, 'Daftar order customer berhasil diambil');
    }
    catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const getProviderOrders = async (req: any, res: Response) => {
    try {
        const providerId = req.user.id;
        const ordersService = new OrdersService();
        const result = await ordersService.getProviderOrders(providerId);
        return successResponse(res, result, 'Daftar order provider berhasil diambil');
    }
    catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const receiveOrderStatus = async (req: any, res: Response) => {
    try {
        const { orderId } = req.params;
        const { status } = req.body;
        const providerId = req.user.id;
        const ordersService = new OrdersService();
        await ordersService.receiveOrderStatus(providerId, orderId, status);
        return successResponse(res, null, `Order berhasil ${status}`);
    }
    catch (err: any) {
        return errorResponse(res, err.message);
    }
};

export { createOrder, getOrderDetails, getCustomerOrders, getProviderOrders, receiveOrderStatus };
