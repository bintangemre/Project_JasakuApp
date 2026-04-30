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

/**
 * @swagger
 * /api/auth/register/provider:
 *   post:
 *     summary: Register provider
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - full_name
 *               - email
 *               - password
 *             properties:
 *               full_name:
 *                 type: string
 *                 example: Budi Santoso
 *               nickname:
 *                 type: string
 *                 example: Budi
 *               email:
 *                 type: string
 *                 example: budi@mail.com
 *               password:
 *                 type: string
 *                 example: 123456
 *               phone:
 *                 type: string
 *                 example: 08123456789
 *               birthDate:
 *                 type: string
 *                 example: 1995-06-15
 *               gender:
 *                 type: string
 *                 example: Laki-laki
 *               address:
 *                 type: string
 *                 example: Pontianak
 *               domicile:
 *                 type: string
 *                 example: Pontianak
 *               profile_photo:
 *                 type: string
 *               ktp_photo:
 *                 type: string
 *               selfie_ktp_photo:
 *                 type: string
 *     responses:
 *       201:
 *         description: Registrasi berhasil
 */

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Login user
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
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 minLength: 6
 *                 example: password123
 *             required:
 *               - email
 *               - password
 *     responses:
 *       200:
 *         description: Login berhasil
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
 *                   example: Login berhasil
 *                 data:
 *                   type: object
 *                   properties:
 *                     token:
 *                       type: string
 *                       example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *       400:
 *         description: Bad Request
 *       401:
 *         description: Invalid credentials
 */

/**
 * @swagger
 * /api/services/categories:
 *   get:
 *     summary: Get all categories
 *     tags: [Services]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Items per page
 *     responses:
 *       200:
 *         description: List of categories
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Unauthorized
 */

/**
 * @swagger
 * /api/services/categories/{id}:
 *   get:
 *     summary: Get category by ID
 *     tags: [Services]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Category ID
 *     responses:
 *       200:
 *         description: Category details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *       404:
 *         description: Category not found
 *       401:
 *         description: Unauthorized
 */

export {};
