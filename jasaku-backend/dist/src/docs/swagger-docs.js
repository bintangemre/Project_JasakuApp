/**
 * @swagger
 * /api/auth/register/customer:
 *   post:
 *     summary: Register customer
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: customer@mail.com
 *               password:
 *                 type: string
 *                 minLength: 6
 *                 example: password123
 *             required:
 *               - email
 *               - password
 *     responses:
 *       201:
 *         description: Customer registration berhasil
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: Customer registered successfully
 *       400:
 *         description: Bad Request
 *       409:
 *         description: Email already exists
 */
export {};
