const request = require('supertest');
const app = require('./server');

describe('GreenRoad API Tests', () => {
  describe('GET /', () => {
    it('should return welcome message', async () => {
      const res = await request(app).get('/');
      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('message');
      expect(res.body.message).toContain('GreenRoad');
    });
  });

  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const res = await request(app).get('/health');
      expect(res.statusCode).toBe(200);
      expect(res.body.status).toBe('healthy');
    });
  });

  describe('GET /ready', () => {
    it('should return ready status', async () => {
      const res = await request(app).get('/ready');
      expect(res.statusCode).toBe(200);
      expect(res.body.status).toBe('ready');
    });
  });

  describe('GET /metrics', () => {
    it('should return prometheus metrics', async () => {
      const res = await request(app).get('/metrics');
      expect(res.statusCode).toBe(200);
      expect(res.headers['content-type']).toContain('text/plain');
    });
  });

  describe('GET /api/info', () => {
    it('should return application info', async () => {
      const res = await request(app).get('/api/info');
      expect(res.statusCode).toBe(200);
      expect(res.body.name).toBe('greenroad');
    });
  });

  describe('GET /api/demo', () => {
    it('should return demo routes', async () => {
      const res = await request(app).get('/api/demo');
      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('routes');
      expect(Array.isArray(res.body.routes)).toBe(true);
    });
  });

  describe('GET /nonexistent', () => {
    it('should return 404', async () => {
      const res = await request(app).get('/nonexistent');
      expect(res.statusCode).toBe(404);
    });
  });
});
