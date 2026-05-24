import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/providers/auth_provider.dart';
import 'package:veducation_app/services/api_service.dart';
import 'package:veducation_app/screens/duel/registration_success_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PaymentScreen extends StatefulWidget {
  final String duelId;
  final double registrationFee;
  final String name;
  final String upiMobile;

  const PaymentScreen({
    super.key,
    required this.duelId,
    required this.registrationFee,
    required this.name,
    required this.upiMobile,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _apiService = ApiService();
  final _razorpay = Razorpay();
  bool _isLoading = false;
  String? _orderId;
  String? _paymentId;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    setState(() => _isLoading = true);

    try {
      // Create order on backend
      final response = await _apiService.createPaymentOrder({
        'duel_id': widget.duelId,
        'amount': widget.registrationFee,
        'name': widget.name,
        'upi_mobile': widget.upiMobile,
      });

      if (response.statusCode == 200) {
        final orderData = response.data;
        _orderId = orderData['order_id'];
        
        // Open Razorpay payment
        final options = {
          'key': orderData['razorpay_key'], // Get from backend
          'amount': (widget.registrationFee * 100).toInt(), // Amount in paise
          'name': 'V Education',
          'description': 'Duel Registration Fee',
          'prefill': {
            'contact': widget.upiMobile,
            'name': widget.name,
          },
          'external': {
            'wallets': ['upi'], // Force UPI payment
          },
        };

        _razorpay.open(options);
      } else {
        _showError('Failed to create payment order');
      }
    } catch (e) {
      _showError('Error initiating payment: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Verify payment on backend
      final verifyResponse = await _apiService.verifyPayment({
        'order_id': _orderId,
        'payment_id': response.paymentId,
        'signature': response.signature,
        'duel_id': widget.duelId,
        'name': widget.name,
        'upi_mobile': widget.upiMobile,
      });

      if (verifyResponse.statusCode == 200) {
        final data = verifyResponse.data;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegistrationSuccessScreen(
                duelId: widget.duelId,
                registrationId: data['registration_id'],
              ),
            ),
          );
        }
      } else {
        _showError('Payment verification failed');
      }
    } catch (e) {
      _showError('Error verifying payment: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showError('Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showError('External wallet selected: ${response.walletName}');
  }

  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pay with UPI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '₹${widget.registrationFee.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Less than a single tea ☕',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Name', widget.name),
                    const Divider(),
                    _buildInfoRow('UPI Mobile', widget.upiMobile),
                    const Divider(),
                    _buildInfoRow('Amount', '₹${widget.registrationFee.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _initiatePayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Pay Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'You will be redirected to UPI payment gateway',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
