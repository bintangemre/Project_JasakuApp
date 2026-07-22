import { Router } from 'express';
import { prisma } from '../../config/prisma';

const router = Router();

// GET /api/wilayah/provinsi
router.get('/provinsi', async (_req, res) => {
  const rows = await prisma.wilayah.findMany({
    where: { level: 'provinsi' },
    select: { code: true, name: true },
    orderBy: { name: 'asc' },
  });
  res.json({ data: rows });
});

// GET /api/wilayah/kota?provinsi=63
router.get('/kota', async (req, res) => {
  const { provinsi } = req.query;
  if (!provinsi) return res.status(400).json({ message: 'provinsi query parameter required' });

  const rows = await prisma.wilayah.findMany({
    where: { level: 'kabupaten', parent_code: provinsi as string },
    select: { code: true, name: true },
    orderBy: { name: 'asc' },
  });
  res.json({ data: rows });
});

// GET /api/wilayah/kecamatan?kota=63.71
router.get('/kecamatan', async (req, res) => {
  const { kota } = req.query;
  if (!kota) return res.status(400).json({ message: 'kota query parameter required' });

  const rows = await prisma.wilayah.findMany({
    where: { level: 'kecamatan', parent_code: kota as string },
    select: { code: true, name: true },
    orderBy: { name: 'asc' },
  });
  res.json({ data: rows });
});

// GET /api/wilayah/kelurahan?kecamatan=63.71.01
router.get('/kelurahan', async (req, res) => {
  const { kecamatan } = req.query;
  if (!kecamatan) return res.status(400).json({ message: 'kecamatan query parameter required' });

  const rows = await prisma.wilayah.findMany({
    where: { level: 'kelurahan', parent_code: kecamatan as string },
    select: { code: true, name: true },
    orderBy: { name: 'asc' },
  });
  res.json({ data: rows });
});

export default router;
