import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { DataSource } from 'typeorm';
import { ok, err, ApiResponse as AppApiResponse } from '@myapp/api/common';

interface HealthStatus {
  status: 'ok' | 'degraded' | 'unhealthy';
  timestamp: string;
  services: {
    database: 'ok' | 'error';
  };
}

@Controller('health')
@ApiTags('health')
export class HealthController {
  constructor(private readonly dataSource: DataSource) {}

  @Get()
  @ApiOperation({ summary: 'Health check endpoint' })
  @ApiResponse({ status: 200, description: 'Service is healthy' })
  @ApiResponse({ status: 503, description: 'Service is unhealthy' })
  async check(): Promise<AppApiResponse<HealthStatus>> {
    const timestamp = new Date().toISOString();
    let databaseStatus: 'ok' | 'error' = 'ok';

    try {
      await this.dataSource.query('SELECT 1');
    } catch {
      databaseStatus = 'error';
    }

    const overallStatus =
      databaseStatus === 'ok' ? 'ok' : 'unhealthy';

    if (overallStatus === 'unhealthy') {
      return err('SERVICE_UNHEALTHY', 'One or more services are unhealthy');
    }

    return ok({
      status: overallStatus,
      timestamp,
      services: {
        database: databaseStatus,
      },
    });
  }

  @Get('live')
  @ApiOperation({ summary: 'Liveness probe' })
  live(): AppApiResponse<{ status: 'ok' }> {
    return ok({ status: 'ok' });
  }

  @Get('ready')
  @ApiOperation({ summary: 'Readiness probe' })
  async ready(): Promise<AppApiResponse<{ status: 'ok' }>> {
    try {
      await this.dataSource.query('SELECT 1');
      return ok({ status: 'ok' });
    } catch {
      return err('NOT_READY', 'Database connection not ready');
    }
  }
}
